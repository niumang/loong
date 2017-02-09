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
use Loong::DB::Mango;
use Loong::Queue;
use Loong::Config;
use Loong::Queue::Worker;
use Loong::Utils::Scraper;

use constant MAX_CURRENCY => 20;
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
has queue_name   => sub { join('_', 'crawl', shift->seed) };
has queue => sub { Loong::Queue->new(mysql => (shift->config->mysql_uri)) };
has worker => sub { shift->queue->repair->worker };
has mango  => sub { Loong::DB::Mango->new(shift->config->mango_uri) };
has 'scraper';

sub new {
    my $self = shift->SUPER::new(@_);
    $self->_spec_scraper;

    return $self if DEBUG;

    $self->first_blood and $self->log->debug("添加task回调任务");
    $self->queue->add_task(crawl => sub { shift->emit('crawl', shift) });
    $self->on(empty      => sub { $self->log->debug("没有任务了"); });
    $self->on(crawl_fail => sub { $self->handle_failed_task(@_) },);
    return $self;
}

sub handle_failed_task {
    my ($self, $url, $context) = @_;
    delete $context->{$_} for qw(ua tx);
    my $args = {url => $url, context => $context};
    $self->log->debug("添加失败的 url -> $url 重新爬");
    $self->log->debug("minion 参数: " . Dump $args) if DEBUG;
    $self->queue->enqueue('crawl', [$args], {queue => $self->queue_name}) unless DEBUG;
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
        my $args = {url => $url, context => $self->extra_config};
        $self->queue->enqueue('crawl' => [$args] => {queue => $self->queue_name,});
        $self->log->debug("加入种子任务: url => $url");
    }

    return 1;
}

sub init {
    my ($self, $url) = @_;
    $url ||= $self->seed;

    my $id = Mojo::IOLoop->recurring(
        $self->shuffle => sub {
            while(1){
                my $job = $self->worker->register->dequeue($self->shuffle, {queues => [$self->queue_name]});

                return $self->emit('empty') unless $job;

                my $task_info = $job->args->[0];
                my $url       = $task_info->{url};
                return if $self->ua->active_conn >= $self->max_currency
                    || !$url
                    || $self->ua->active_host($url) >= $self->site_config->{ua}{max_active};
                $self->process_job($url, $task_info->{context});
            }
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
    my ($self, $url, $context) = @_;

    my $tx = $self->prepare_http($url);
    $context->{ua}           = $self->ua;
    $context->{tx}           = $tx;
    $context->{base}         = $self->seed;
    $context->{extra_config} = $self->extra_config;
    $context->{parent} ||= '';

    $self->log->info("开始抓取 url => $url");
    $self->ua->start(
        $tx => sub {
            my ($ua, $tx) = @_;
            my $ret;
            $self->log->debug("上一层页面 $context->{parent}") unless DEBUG;
            eval { $ret = $self->scrape($tx, $context) };
            if (my $collection = $ret->{collection}) {
                for my $item (@{$ret->{data}}) {
                    $item->{parent}  = $context->{parent};
                    $item->{url_md5} = md5_hex $item->{url};
                    unless(DEBUG){
                        $self->log->debug("保存到 mango collection-<$collection>: " . Dump($item));
                        $self->mango->save_crawl_info($item, $self->seed, $collection);
                    }
                }
            }

            return $self->stop if DEBUG;
            $self->continue_with_scraped($_, "$url", $context) for @{$ret->{nexts}};
        },
    );
}

sub _spec_scraper {
    my ($self, $domain) = @_;
    $domain ||= $self->seed;
    $domain =~ s/www.//g;
    $domain =~ s/www.//g;
    my $alias = $self->site_config->{entry}->{alias};
    my $pkg = join('::','Loong','Scraper',ucfirst( $alias ? $alias : [split('\.', $domain)]->[0]) );
    my $scraper;
    eval {
        load_class $pkg;
        $scraper = $pkg->new( domain => $domain );
    };
    if($@){
        $self->log->error("加载 scraper 模块失败 $@");
        die $@;
    }
    $self->scraper($scraper);
}

sub scrape {
    my ($self, $tx, $context) = @_;
    my $res = $tx->res;
    my $url = $tx->req->url;
    my $ret;

    if (!$res->headers->content_length or !$res->body) {
        $context->{fail}++ and $self->emit('crawl_fail', "$url", $context);
        $self->log->error("下载 url => $url 失败, 原因: $res->code");
        return;
    }
    my $type   = $res->headers->content_type;
    my $method = $tx->req->method;

    # TODO support img and file content
    # TODO add scraper cached in memory
    $self->cache_resouce($tx) if DEBUG;
    if ($type && $type =~ qr{^(text|application)/(html|xml|xhtml|javascript)}) {
        eval {
            $ret = $self->scraper->scrape($url, $res, $context);
            $self->log->debug("解析 url => $url  => " . Dump($ret));
        };
        if ($@) {
            $context->{fail}++ and $self->emit('crawl_fail', "$url", $context);
            $self->log->debug("解析 html 文档失败: $@, 傻逼网站换代码了,检查下载的html文件吧");
        }
    }

    return $ret;
}

sub continue_with_scraped {
    my ($self, $next, $parent, $ctx) = @_;
    delete $ctx->{$_} for qw(ua tx);
    my $args = {url => $next->{url}, context => {%$ctx, parent => $parent}};
    $self->log->debug("添加下一层 url -> $next->{url} 到 task 队列");
    $self->log->debug("minion 参数: " . Dump $args) if DEBUG;
    $self->queue->enqueue('crawl', [$args], {queue => $self->queue_name}) unless DEBUG;
}

# todo: prepare cookie proxy pre-request post request
sub prepare_http {
    my ($self, $url) = @_;

    $self->scraper->match($url);
    my ($method,$headers,$form) = ($self->scraper->method,$self->scraper->headers,$self->scraper->form);
    $self->log->debug("请求 $url ******\n" . sprintf('method=%s, headers=%s, form=%s',
            $method,dumper $headers,dumper $form) );
    my @args;
    push @args,$headers if $headers;
    push @args,(form => $form) if $form;

    return $self->ua->build_tx( uc $method => $url => @args);
}

sub shuffle {
    return rand(1);
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
