package Loong::Crawler;

use Carp;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::URL;
use Mojo::DOM;
use Mojo::Util qw(dumper);
use YAML qw(Dump);
use Mojo::Loader qw(load_class);
use Encode qw(decode_utf8);

use Loong::Mojo::Log;
use Loong::Mojo::UserAgent;

#use Loong::Mojo::UserAgent::Proxy;
#use Loong::Mojo::UserAgent::CookieJar;
use Loong::Queue;
use Loong::Queue::Worker;
use Loong::Utils::Scraper;
use Loong::Mojo::Exception;

use constant MAX_CURRENCY => 100;
use constant DEBUG        => $ENV{LOONG_DEBUG};

has 'seed' => sub { $_[1] =~ s{http://}{}g; $_[1] };
has max_currency => sub { MAX_CURRENCY };
has log          => sub { Loong::Mojo::Log->new };

# TODO suport save cookie cache
#has cookie => sub { Loong::Mojo::UserAgent::CookieJar->new };
has ua           => sub { Loong::Mojo::UserAgent->new };
has url          => sub { Mojo::URL->new };
has extra_config => sub { {} };

# TODO support proxy for http request
#has proxy => sub { Loong::Mojo::UserAgent::Proxy->new };
has ua_name    => sub { 'fuck' };
has io_loop    => sub { Mojo::IOLoop->new };
has task_name  => sub { 'crawl' };
has queue_name => sub { 'crawl_' . ( shift->seed || '' ) };
has queue => sub {
    Loong::Queue->new( mysql => 'mysql://root:root@127.0.0.1/minion_jobs' );
};
has worker    => sub { shift->queue->repair->worker };
has _loop_ids => sub { [] };

sub new {
    my $self = shift->SUPER::new(@_);

    return $self if DEBUG;

    $self->first_blood and $self->log->debug("添加task回调任务");
    $self->queue->add_task( $self->task_name => sub { shift->emit( 'crawl', shift ) } );
    $self->on( empty => sub {
            $self->log->debug("没有任务了！");
            $self->stop;
        }
    );
    return $self;
}

sub first_blood {
    my ($self) = @_;
    my $url = $self->seed =~ m/^http/ ? $self->seed : 'http://' . $self->seed;
    $self->log->debug("加入种子任务: url => $url");
    $self->queue->enqueue(
        'crawl',
        [ { url => $url, extra_config => $self->extra_config } ] => {
            priority => $self->extra_config->{priority} || 0,
            queue => $self->queue_name,
        }
    );
}

sub init {
    my ( $self, $url ) = @_;
    $url ||= $self->seed;

    my $id = Mojo::IOLoop->recurring(
        0 => sub {
            my $job = $self->worker->register->dequeue( $self->shuffle,
                { queues => [ $self->queue_name ] } );

            return unless $job;

            my $task_info = $job->args->[0];
            my $url       = $task_info->{url};

            return
                 if $self->ua->active_conn >= $self->max_currency
              || !$url
              || $self->ua->active_host($url) >= $self->max_currency;

            $self->process_job( $url, $task_info->{extra_config} );
        },
    );
    push @{ $self->_loop_ids }, $id;
    return $self;
}

sub beta_crawl { shift->process_job(@_) }

sub stop {
    my ($self) = @_;
    for my $id ( @{ $self->_loop_ids } ) {
        Mojo::IOLoop->remove($_) for @{ $self->_loop_ids };
    }
    Mojo::IOLoop->stop;
}

sub fuck { Mojo::IOLoop->start unless Mojo::IOLoop->is_running }

sub process_job {
    my ( $self, $url, $extra_config ) = @_;

    my $tx      = $self->prepare_http($url);
    my $context = {};
    $context->{ua}           = $self->ua;
    $context->{emitter}      = $self->io_loop;
    $context->{extra_config} = $self->extra_config;
    $context->{tx}           = $tx;
    $context->{base}         = $self->seed;

    $self->log->debug("开始抓取 url => $url");
    $self->ua->start(
        $tx => sub {
            my ( $ua, $tx ) = @_;
            my $ret = $self->scrape( $tx, $context );

            return $self->stop if DEBUG;

            my $nexts = $ret->{nexts};
            while ( my $item = shift @$nexts ) {
                $self->log->debug("攥取下一个页面 $item->{url}");
                $self->continue_with_scraped( $ret->{url}, $item,
                    $self->extra_config );
            }
        },
    );
}

sub scrape {
    my ( $self, $tx, $context ) = @_;
    my $res = $tx->res;
    my $ret;

    return unless $res->headers->content_length && $res->body;

    my $url    = $tx->req->url;
    my $type   = $res->headers->content_type;
    my $method = $tx->req->method;
    my $domain = $self->seed;
    $domain =~ s/www.//g;
    my $pkg = 'Loong::Scraper::' . ucfirst( [ split( '\.', $domain ) ]->[0] );
    $self->log->debug("查找到解析的模块 $pkg");

    if ( $type && $type =~ qr{^(text|application)/(html|xml|xhtml)} ) {
        eval {
            # TODO add scraper cached in memory
            load_class $pkg;
            my $scraper = $pkg->new;
            $ret = $scraper->find( $method => $url )->scrape( $res, $context );
            $self->log->debug( "解析 url => $url  => " . Dump($ret) );
        };
        if ($@) {
            $self->log->debug("解析 html 文档失败 $@");
        }
    }

    return $ret;
}

sub continue_with_scraped {
    my ( $self, $previous, $next, $ctx ) = @_;

    my $args = {
        url          => $next->{url},
        previous_url => $previous,
        extra_config => $ctx,
    };
    $self->queue->enqueue( 'crawl', [$args], { queue => $self->queue_name } );
}

sub prepare_http {
    my ( $self, $url ) = @_;

    #$self->emit($_) for qw( cookie ip_pool pre_form);
    my $method  = $self->extra_config->{method} || 'get';
    my $headers = $self->extra_config->{headers};
    my $form    = $self->extra_config->{form};

    $self->ua->transactor->name( $self->ua_name );
    $self->ua->max_redirects(5);

    my @args = ( $method, $url );
    push( @args, form    => $_ ) if $form;
    push( @args, headers => $_ ) if $headers;

    $self->log->debug( "准备好 http 参数" . dumper( \@args ) );
    return $self->ua->build_tx(@args);
}

sub shuffle {
    return rand(2);
}

sub clock_speed {
}

1;

