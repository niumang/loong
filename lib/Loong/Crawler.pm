package Loong::Crawler;

use Carp;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::URL;
use Mojo::DOM;
use Mojo::Utils qw(dumper);

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

has max_currency => sub { MAX_CURRENCY };
has log          => sub { Loong::Mojo::Log->new };
has subcriber;
# TODO suport save cookie cache
#has cookie => sub { Loong::Mojo::UserAgent::CookieJar->new };
has ua           => sub { Loong::Mojo::UserAgent->new };
has url          => sub { Mojo::URL->new };
has extra_config => sub { {} };

# TODO support proxy for http request
#has proxy => sub { Loong::Mojo::UserAgent::Proxy->new };
has ua_name   => sub { 'fuck' };
has io_loop   => sub { Mojo::IOLoop->new };
has queue     => sub { Loong::Queue->new( mysql => 'mysql://root:root@127.0.0.1/minion_jobs' ) };
has worker => sub { shift->queue->repair->worker };
has _loop_ids => sub { [] };

my @beta_urls = (
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
    { url => "http://www.hhssee.com/manhua10492.html"},
);

sub new{
    my $self = shift->SUPER::new(@_);

    $self->on( crawl => sub {
            my ($task_info) = @_;
            my $url = $task_info->{url};
            return
                 if $self->ua->active_conn >= $self->max_currency
              || !$url
              || $self->ua->active_host($url) >= $self->max_currency;
            $self->process_job($url);
        }
    );
    $self->on( empty => sub { say "没有任务了！" };
    Carp::croak "请输入你需要抓取的网站域名" unless DEBUG;
    return $self;
}

sub crawl {
    my ($self,$url) = @_;
    $url ||= $self->subcriber;

    return $self->beta_crawl($url) if DEBUG;

    my $id = Mojo::IOLoop->recurring(
        $self->emit('dequeue', $self->subcriber) unless DEBUG;
    );
    push @{ $self->_loop_ids }, $id;
}

sub beta_crawl{ shift->process_job(@_) }

sub stop {
    my ($self) = @_;
    for my $id ( @{ $self->_loop_ids } ) {
        Mojo::IOLoop->remove($_) for @$self->_loop_ids;
    }
    Mojo::IOLoop->stop;
}

sub fuck{ Mojo::IOLoop->run unless Mojo::IOLoop->is_running; }

sub process_job {
    my ( $self, $url ) = @_;

    my $tx      = $self->prepare_http($url);
    my $context = {};
    $context->{ua}           = $self->ua;
    $context->{emitter}      = $self->io_loop;
    $context->{extra_config} = $self->extra_config;
    $context->{tx}           = $tx;

    $self->log->debug(" extra_config = ".dumper($extra_config));
    $self->log->debug(" context = ".dumper($context));

    $self->ua->start(
        $tx => sub {
            my ( $ua, $tx ) = @_;
            # TODO process http download failed ,enqueue url to next task
            my $ret = $self->scrape( $tx, $context );

            return if DEBUG;

            my $nexts = $ret->{nexts};
            while( my $item = shift @$nexts){
                my $queue = Mojo::URL->new($item->{url})->ihost;
                $self->log->debug("攥取下一个页面 $item->{url}");
                $self->emit('enqueue',$queue,$item) unless DEBUG;
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
    my $domain = Mojo::URL->new($url)->ihost;
    $domain =~ s/www.//g;
    my $pkg = 'Loong::Scraper::' . ucfirst( [ split( '\.', $domain ) ]->[0] );
    $self->log->debug("查找到解析的模块 $pkg");

    if ( $type && $type =~ qr{^(text|application)/(html|xml|xhtml)} ) {
        eval {
            # TODO decode_body
            my $dom = Mojo::DOM->new($res->body);
            $pkg->import;
            my $scraper = $pkg->new;
            my $ret = $scraper->index( $method => $url )->scrape( $dom, $context );
            $self->log->debug("解析 url => $url dom => ".dumper($ret);
        };
    }

    return $ret;
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
    
    $self->log->debug("准备好 http 参数".dumper(\@args));
    return $self->ua->build_tx(@args);
}

sub shuffle {
}

sub clock_speed {
}

1;

