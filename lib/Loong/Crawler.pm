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
use Mojo::UserAgent::CookieJar;

use Loong::Queue;
use Loong::Config;
use Loong::Filter;
use Loong::Mojo::Log;
use Loong::Mojo::UserAgent;
use Loong::Mojo::UserAgent::CookieJar;
use Loong::Mojo::Exception;
use Loong::DB::Mango;
use Loong::Queue::Worker;
use Loong::Utils::Scraper;

use constant MAX_CONCURRENT => 20;
use constant DEBUG => $ENV{LOONG_DEBUG} || 0;

has max_concurrent => MAX_CONCURRENT;
has seed => sub { $_[1] =~ s{http://}{}g; $_[1] };
has config       => sub { Loong::Config->new };
has log          => sub { Loong::Mojo::Log->new };
has ua           => sub { Loong::Mojo::UserAgent->new };
has extra_config => sub { shift->site_config };
has max_active   => sub { shift->site_config->{ua}->{max_active} };
has queue_name   => sub { join( '_', 'crawl', shift->seed ) };
has queue => sub { Loong::Queue->new( mysql => ( shift->config->mysql_uri ) ) };
has mango => sub { Loong::DB::Mango->new( shift->config->mango_uri ) };
has bloom => sub { Loong::Filter->new };
has is_debug => DEBUG;
has filter   => 0;
has cache    => 0;
has 'scraper';

sub new {
    my $self = shift->SUPER::new(@_);

    $self->_spec_scraper;
    if ( my $proxy = $self->site_config->{ua}->{proxy} ) {
        $self->ua->proxy->http( 'http://' . $proxy )->https( 'https://' . $proxy );
    }
    if ( my $jar = $self->site_config->{ua}->{cookie_jar} ) {
        $self->ua->cookie_jar( Mojo::UserAgent::CookieJar->new );
        $self->ua->get($jar);
    }
    $self->log->debug( "cookie =" . dumper( $self->ua->cookie_jar ) );

    return $self if DEBUG;

    $self->queue->add_task( crawl => sub { shift->emit( 'crawl', shift ) } );
    $self->on( empty        => sub { $self->log->debug("暂时没有任务了") } );
    $self->on( crawl_fail   => sub { shift->queue->update_failed_task(@_) } );
    $self->on( crawl_finish => sub { shift->queue->finished_task(@_) } );

    return $self;
}

sub handle_failed_task {
    my ( $self, $url, $context ) = @_;
    delete $context->{$_} for qw(ua tx);
    my $args = { url => $url, context => $context };
    $self->log->debug("添加失败的 url -> $url 重新爬");
    $self->queue->enqueue( 'crawl', [$args], { queue => $self->queue_name } )
      unless $self->is_debug;
}

sub site_config {
    my ($self) = @_;
    ( my $s = $self->seed ) =~ s/www.//g;
    return $self->config->{site}->{$s}->{crawl};
}

sub first_blood {
    my ( $self, $url ) = @_;

    # 根据参数指定的url压入发送队列
    if ($url) {
        my $args = { url => $url, context => $self->extra_config };
        $self->log->info("加入种子任务: url => $url");
        return $self->queue->enqueue( 'crawl' => [$args] => { queue => $self->queue_name, } );
    }

    my $home = $self->site_config->{entry}{home};
    $url ||= $self->seed =~ m/^http/ ? $self->seed : 'http://' . $self->seed;
    $home =~ s/www.//g;
    Carp::croak "没有定义网站的入口 $home\n" unless $home;
    for my $url ( split( ',', $home ) ) {
        my $args = { url => $url, context => $self->extra_config };
        $self->queue->enqueue( 'crawl' => [$args] => { queue => $self->queue_name, } );
        $self->log->info("加入种子任务: url => $url");
    }

    return 1;
}

sub init {
    my ( $self, $url ) = @_;
    $url ||= $self->seed;

    my $interval = $self->site_config->{ua}->{interval} || $self->shuffle;
    my $worker   = $self->queue->repair->worker->register;
    my $id       = Mojo::IOLoop->recurring(
        rand($interval) => sub {
            while (1) {
                my $job = $worker->dequeue( 0, { queues => [ $self->queue_name ] } );

                return $self->emit('empty') unless $job;

                my $task_info = $job->args->[0];
                my $url       = $task_info->{url};
                if ( $self->filter && $self->bloom->is_crawled($url) ) {
                    $self->log->info("链接: $url 已经爬过了");
                    return;
                }
                return
                  if ( $self->ua->active_conn && $self->ua->active_conn >= $self->max_concurrent )
                  || !$url
                  || $self->ua->active_host($url) >= $self->max_active;
                $self->process_job( $url, $task_info->{context}, $job );
            }
        },
    );
    push @{ $self->{_loop_id} }, $id;
    return $self;
}

sub beta_crawl { shift->process_job(@_) }

sub stop {
    Mojo::IOLoop->remove($_) for @{ $_[0]->{_loop_id} };
    Mojo::IOLoop->stop;
}

sub fuck { Mojo::IOLoop->start unless Mojo::IOLoop->is_running }

sub handle_res_status {
    my ( $self, $tx, $job ) = @_;

    if ( $tx->res->is_success ) {
        $self->log->debug( $tx->res->body ) if $self->is_debug;
    }
    elsif ( $tx->res->is_error ) {
        $self->queue->update_failed_task( $job, $tx->res->message );
        Carp::croak '下载出错了: ' . $tx->res->message;
    }
    elsif ( $tx->res->code == 301 ) {
        Carp::croak '你被重定向了到：' . $tx->res->headers->location;
    }
    else {
        Carp::croak '到底哦该了';
    }
    return;
}

sub process_job {
    my ( $self, $url, $context, $job ) = @_;

    my ( $matched, $tx ) = $self->prepare_http($url);
    $context->{ua}           = $self->ua;
    $context->{tx}           = $tx;
    $context->{base}         = $self->seed;
    $context->{extra_config} = $self->extra_config;
    $context->{job}          = $job;
    $context->{parent} ||= '';
    $context->{matched} = $matched;

    $self->log->info("开始抓取 url => $url");
    $self->ua->start(
        $tx => sub {
            my ( $ua, $tx ) = @_;
            my $ret;
            eval {
                $self->log->debug("上一层页面 $context->{parent}");
                $ret = $self->scrape( $tx, $context );
                my $collection = $tx->req->headers->header('collection') || $ret->{collection};
                if ( !$self->is_debug and $collection ) {
                    for my $item ( @{ $ret->{data} } ) {
                        $item->{parent}  = $context->{parent};
                        $item->{url_md5} = md5_hex $item->{url};
                        $self->log->debug( "保存到 collection=$collection " . Dump($item) );
                        $self->mango->save_crawl_info( $item, $self->seed, $collection );
                    }
                }
                $self->emit( 'crawl_finish', $job, '总算是爬完了' );
            };
            if ($@) {
                $self->log->error("解析失败: $@");
                $self->emit( 'crawl_fail', $job, '解析失败: $@' );
            }
            $self->log->debug( "解析结果: " . Dump($ret) );
            $self->bloom->crawled($url) if !$self->is_debug and $ret->{data};

            return $self->stop if $self->is_debug;

            $self->continue_with_scraped( $_, "$url", $context ) for @{ $ret->{nexts} };
        },
    );
}

sub _spec_scraper {
    my ( $self, $domain ) = @_;
    $domain ||= $self->seed;
    $domain =~ s/www.//g;

    my $alias = $self->site_config->{entry}->{alias};
    my $pkg =
      join( '::', 'Loong', 'Scraper',
        ucfirst( $alias ? $alias : [ split( '\.', $domain ) ]->[0] ) );
    my $scraper;
    eval {
        load_class $pkg;
        $scraper = $pkg->new( domain => $domain );
    };
    if ($@) {
        $self->log->error("加载 scraper 模块失败 $@");
        die $@;
    }
    return $self->scraper($scraper);
}

sub scrape {
    my ( $self, $tx, $context ) = @_;
    my $res = $tx->res;
    my $url = $tx->req->url;
    my $ret;

    if ( !$res->headers->content_length or !$res->body ) {
        return $self->emit( 'crawl_fail', $context->{job}, '下载页面失败: $@' );
    }
    my $type   = $res->headers->content_type;
    my $method = $tx->req->method;

    # TODO support img and file content
    # TODO add scraper cached in memory
    $self->cache_resouce($tx) if $self->is_debug;
    if ( $type && $type =~ qr{^(text|application)/(html|xml|xhtml|javascript)} ) {
        eval { $ret = $self->scraper->scrape( $url, $res, $context ); };
        if ( $@ || @{ $ret->{data} } == 0 ) {
            Carp::croak "解析 html 文档失败: $@, 傻逼网站换代码了,检查下载的html文件吧";
        }
    }

    return $ret;
}

sub continue_with_scraped {
    my ( $self, $next, $parent, $ctx ) = @_;
    delete $ctx->{$_} for qw(ua tx job);
    my $args = { url => $next->{url}, context => { %$ctx, parent => $parent } };
    $self->log->debug("添加下一层 url -> $next->{url} 到 task 队列");
    $self->log->debug( "minion 参数: " . Dump $args);
    $self->queue->enqueue( 'crawl', [$args], { queue => $self->queue_name } )
      unless $self->is_debug;
}

sub prepare_http {
    my ( $self, $url ) = @_;

    my $m = $self->scraper->match($url);

    # 如果没有指定的 useragent 则使用池子里的随机元素
    my $user_agent = $self->site_config->{ua}->{user_agent};
    $self->ua->transactor->name(
        $user_agent =~ m/^web|mobile$/ ? $self->ua->pool->get($user_agent) : $user_agent );

    # 默认开启 cookie
    $self->ua->cookie_jar( Loong::Mojo::UserAgent::CookieJar->new );
    if ( my $script = $self->site_config->{ua}->{cookie_script} ) {
        $self->ua->cookie_jar->cookie_script($script);
    }
    $self->log->debug( "Proxy: " . $self->ua->proxy->http ) if $self->ua->proxy->http;
    $self->log->debug(
        "请求参数"
          . sprintf(
            'method=%s, headers=%s, form=%s',
            $m->{method},
            dumper $m->{header},
            dumper $m->{form}
          )
    );
    my @args;
    push @args, $m->{headers} if $m->{headers};
    push @args, ( form => $m->{form} ) if $m->{form};

    return ( $m, $self->ua->build_tx( uc $m->{method} => $url => @args ) );
}

sub shuffle {
    return rand(1);
}

sub clock_speed {
    return int( rand(60) );
}

sub cache_resouce {
    my ( $self, $tx, $opts ) = @_;

    my $url_md5 = md5_hex( $tx->req->url->to_string );

    # 默认存储到{root}目录/data
    my $cache_dir = File::Spec->catdir( $self->config->root, 'data', $self->seed, $url_md5 );
    if ( not -d $cache_dir ) {
        $self->log->debug("创建缓存目录 : $cache_dir");
        make_path($cache_dir);
    }
    my $file = File::Spec->catfile( $cache_dir, 'cached.html' );
    $tx->res->content->asset->move_to($file);
    $self->log->debug("缓存文件 -> $file 成功");

    return 1;
}

1;
