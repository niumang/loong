package Loong::Crawler;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::URL;
use Mojo::DOM;

use Loong::Mojo::Log;
use Loong::Mojo::UserAgent;

#use Loong::Mojo::UserAgent::Proxy;
#use Loong::Mojo::UserAgent::CookieJar;
use Loong::Queue;
use Loong::Utils::Scraper;
use Loong::Mojo::Exception;

use constant MAX_CURRENCY => 100;
use constant DEBUG        => $ENV{LOONG_DEBUG};

has max_currency => sub { MAX_CURRENCY };
has log          => sub { Loong::Mojo::Log->new };

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

sub crawl {
    my ($self,$url) = @_;

    $url      ||= $self->url;
    my $max_conn = $self->ua->active_conn;
    my $active   = $self->ua->active_conn_per_host;
    my $worker;
    $worker = DEBUG ? undef : $self->queue->repair->worker;

    if(ref $worker){
        $self->on('crawl' => sub {
                my $task_info = shift;
                my $url = $task_info->{url};

                return
                     if $self->ua->active_conn >= $self->max_currency
                  || !$url
                  || $self->ua->active_host($url) >= $self->max_currency;
                $self->process_job($url);
            }
        );
    }else{
        my $id = Mojo::IOLoop->recurring(
            0 => sub {
                if(!ref($worker)){
                    $job = shift @beta_urls;
                }else{
                    $job = $worker->register->dequeue(0);
                }
                if ( !$job and !$self->ua->active_conn) {
                    $self->stop;
                    return;
                }
                my $url = $job->{url};
                return
                     if $self->ua->active_conn >= $self->max_currency
                  || !$url
                  || $self->ua->active_host($url) >= $self->max_currency;

                $self->process_job($url);
            }
        );
        $self->emit('start');
        push @{ $self->_loop_ids }, $id;
    }
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub stop {
    my ($self) = @_;
    for my $id ( @{ $self->_loop_ids } ) {
        Mojo::IOLoop->remove($id);
    }
    Mojo::IOLoop->stop;
}

sub process_job {
    my ( $self, $url ) = @_;

    my $tx      = $self->prepare_http($url);
    my $context = {};
    $context->{ua}           = $self->ua;
    $context->{emitter}      = $self;
    $context->{extra_config} = $self;
    $context->{tx}           = $tx;
    $self->ua->start(
        $tx => sub {
            my ( $ua, $tx ) = @_;
            # process http download failed ,enqueue url to next task
            my $ret = $self->scrape( $tx, $context );
        },
    );
}

sub scrape {
    my ( $self, $tx, $context ) = @_;
    my $res = $tx->res;
    my @ret;

    return unless $res->headers->content_length && $res->body;

    my $url    = $tx->req->url;
    my $type   = $res->headers->content_type;
    my $method = $tx->req->method;
    my $domain = Mojo::URL->new($url)->ihost;
    $domain =~ s/www.//g;
    my $pkg = 'Loong::Scraper::' . ucfirst( [ split( '\.', $domain ) ]->[0] );

    eval {
        if ( $type && $type =~ qr{^(text|application)/(html|xml|xhtml)} ) {
            # TODO decode_body
            my $dom = Mojo::DOM->new($res->body);
            $pkg->import;
            my $scraper = $pkg->new;
            my $ret =
              $scraper->index( $method => $url )->scrape( $dom, $context );
        }
    };

    return @ret;
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

    return $self->ua->build_tx(@args);
}

sub shuffle {
}

sub clock_speed {
}

1;

