package Loong::Crawler;

use Carp;
use YAML qw(Dump);
use File::Spec;
use File::Path qw(make_path remove_tree);
use Digest::MD5 qw(md5_hex);

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::URL;
use Mojo::DOM;
use Mojo::Util qw(dumper);
use Mojo::Loader qw(load_class);

use Loong::Mojo::Log;
use Loong::Mojo::UserAgent;
use Loong::Mojo::Exception;
use Loong::Mango;
use Loong::Queue;
use Loong::Config;
use Loong::Queue::Worker;
use Loong::Utils::Scraper;

use constant MAX_CURRENCY => 2;
use constant DEBUG => $ENV{LOONG_DEBUG} || 0;

# TODO suport save cookie cache
# TODO support proxy for http request
# TODO support db name for seed
has max_currency => MAX_CURRENCY;
has seed => sub { $_[1] =~ s{http://}{}g; $_[1] };
has config       => sub { Loong::Config->new };
has log          => sub { Loong::Mojo::Log->new };
has ua           => sub { Loong::Mojo::UserAgent->new };
has url          => sub { Mojo::URL->new };
has extra_config => sub { shift->site_config };
has queue_name   => sub { 'crawl_' . (shift->seed || '') };
has queue => sub { Loong::Queue->new(mysql => (shift->config->mysql_uri)) };
has worker => sub { shift->queue->repair->worker };
has mango  => sub { Loong::Mango->new(shift->config->mango_uri) };

sub new {
    my $self = shift->SUPER::new(@_);

    return $self if DEBUG;

    $self->first_blood and $self->log->debug("添加task回调任务");
    $self->queue->add_task(crawl => sub { shift->emit('crawl', shift) });
    $self->on(
        empty => sub {
            $self->log->debug("没有任务了！");
            $self->stop;
        }
    );
    return $self;
}

sub site_config {
    my ($self) = @_;
    my $s = $self->seed;
    $s =~ s/www.//g;
    return $self->config->{site}->{$s}->{crawl};
}

sub first_blood {
    my ($self) = @_;
    my $url = $self->seed =~ m/^http/ ? $self->seed : 'http://' . $self->seed;
    my $home = $self->site_config->{entry}{home};
    $home =~ s/www.//g;

    die "没有定义网站的入口 $home\n" unless $home;

    for my $url (split(',', $home)) {
        my $args = {url => $url, extra_config => $self->extra_config};
        $self->queue->enqueue('crawl' => [$args] => {queue => $self->queue_name,});
        $self->log->debug("加入种子任务: url => $url");
    }

    return;
}

sub init {
    my ($self, $url) = @_;
    $url ||= $self->seed;

    my $id = Mojo::IOLoop->recurring(
        0 => sub {
            my $job = $self->worker->register->dequeue($self->shuffle, {queues => [$self->queue_name]});

            return unless $job;

            my $task_info = $job->args->[0];
            my $url       = $task_info->{url};

            return
                 if $self->ua->active_conn >= $self->max_currency
              || !$url
              || $self->ua->active_host($url) >= $self->max_currency;

            $self->process_job($url, $task_info->{extra_config});
        },
    );
    push @{$self->{_loop_id}}, $id;
    return $self;
}

sub beta_crawl { shift->process_job(@_) }

sub stop {
    Mojo::IOLoop->remove($_) for @{$_[0]->{_loop_id}};
    Mojo::IOLoop->stop;
}

sub fuck { Mojo::IOLoop->start unless Mojo::IOLoop->is_running }

sub process_job {
    my ($self, $url, $extra_config) = @_;

    my $tx      = $self->prepare_http($url);
    my $context = {};
    $context->{ua}           = $self->ua;
    $context->{extra_config} = $self->extra_config;
    $context->{tx}           = $tx;
    $context->{base}         = $self->seed;

    $self->log->debug("开始抓取 url => $url");
    $self->ua->start(
        $tx => sub {
            my ($ua, $tx) = @_;
            my $ret = {};
            eval { $ret = $self->scrape($tx, $context) };

            return $self->stop if DEBUG;

            for my $item (@{$ret->{nexts}}) {
                $self->log->debug("获取下一个页面 $item->{url}");
                $self->continue_with_scraped($ret->{url}, $item, $self->extra_config);
            }
            return $self->mango->save_crawl_info($ret, $self->seed);
        },
    );
}

sub scrape {
    my ($self, $tx, $context) = @_;
    my $res = $tx->res;
    my $url = $tx->req->url;
    my $ret;

    if (!$res->headers->content_length or !$res->body) {

        # TODO failed update or enqueue to next url
        $self->log->error("下载 url => $url 失败, 原因: $res->code");
        return;
    }
    my $type   = $res->headers->content_type;
    my $method = $tx->req->method;
    my $domain = $self->seed;
    $domain =~ s/www.//g;
    my $pkg = 'Loong::Scraper::' . ucfirst([split('\.', $domain)]->[0]);
    my $alias = $self->site_config->{entry}->{alias};
    $pkg = 'Loong::Scraper::' . ucfirst($alias) if $alias;

    $self->log->debug("查找到解析的模块 $pkg");

    # TODO support img and file content
    # TODO add scraper cached in memory
    $self->cache_resouce($tx) if DEBUG;
    if ($type && $type =~ qr{^(text|application)/(html|xml|xhtml|javascript)}) {
        eval {
            $context->{type} = $2;
            load_class $pkg;
            my $scraper = $pkg->new;
            $ret = $scraper->find($method => $url)->scrape($res, $context);
            $ret->{url}     = "$url";
            $ret->{url_md5} = md5_hex($ret->{url});
            $self->log->debug("解析 url => $url  => " . Dump($ret));
        };
        if ($@) {
            $self->log->debug("解析 html 文档失败: $@, 傻逼代码出问题了");
        }
    }

    return $ret;
}

sub continue_with_scraped {
    my ($self, $previous, $next, $ctx) = @_;

    my $args = {
        url          => $next->{url},
        parent       => $previous,
        extra_config => $ctx,
    };
    $self->queue->enqueue('crawl', [$args], {queue => $self->queue_name}) unless DEBUG;
}

sub prepare_http {
    my ($self, $url) = @_;

    # TODO prepare cookie proxy pre-request post request
    #$self->emit($_) for qw( cookie ip_pool pre_form);
    my $method  = $self->extra_config->{method} || 'get';
    my $headers = $self->extra_config->{headers};
    my $form    = $self->extra_config->{form};
    my @args    = ($method, $url);
    push(@args, form    => $form)    if $form;
    push(@args, headers => $headers) if $headers;

    $self->log->debug("准备好 http 参数" . dumper(\@args));

    return $self->ua->build_tx(@args);
}

sub shuffle {
    return rand(2);
}

sub clock_speed {
}

sub cache_resouce {
    my ($self, $tx, $opts) = @_;

    my $url_md5 = md5_hex($tx->req->url->to_string);

    # 默认存储到{root}目录/data
    my $cache_dir = File::Spec->catdir($self->config->root, 'data', $self->seed, $url_md5);
    if (not -d $cache_dir) {
        $self->log->debug("创建缓存目录 : $cache_dir");
        make_path($cache_dir);
    }
    my $file = File::Spec->catfile($cache_dir, 'cached.html');
    $tx->res->content->asset->move_to($file);
    $self->log->debug("缓存文件 -> $file 成功");

    return 1;
}


1;

