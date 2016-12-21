package Loong::Crawler;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::URL;
use Mojo::DOM;

use Loong::Mojo::Log;
use Loong::Mojo::UserAgent;
#use Loong::Mojo::UserAgent::Proxy;
#use Loong::Mojo::UserAgent::CookieJar;
use Loong::Utils::Scraper;
use Loong::Mojo::Exception;

use constant MAX_CURRENCY => 100;
use constant DEBUG => 0;

has max_currency => sub { MAX_CURRENCY };
has log => sub { Loong::Mojo::Log->new };
# TODO suport save cookie cache
#has cookie => sub { Loong::Mojo::UserAgent::CookieJar->new };
has ua => sub { Loong::Mojo::UserAgent->new };
has url => sub { Mojo::URL->new };
has extra_config => sub { {} };
# TODO support proxy for http request
#has proxy => sub { Loong::Mojo::UserAgent::Proxy->new };
has ua_name => sub { 'fuck' };
has io_loop => sub { Mojo::IOLoop->new };
has queue = sub { Minion->new(Pg => 'postgresql://postgres@/test');

sub crawl{
    my $self= shift;

    my $tx = $self->init(@_);
    my $url = $self->url;
    my $max_conn = $self->ua->active_conn;
    my $active = $self->ua->active_conn_per_host;
    my $worker = $minion->repair->worker;

    $self->on('empty', sub { say "Queue is drained out."; $self->stop })

    Mojo::IOLoop->recurring(
        0 => sub {
            my $job = $worker->register->dequeue(0);
            if(not $job){
                Mojo::IOLoop->stop;
                return;
            }

            my $url = $job->{url};
            return if !$url;
            return if $self->ua->active_conn >= $self->max_currency;
            return if $self->ua->active_host($url) >= $self->max_currency;

            $self->process_job($url);
        }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub process_job{
    my ($self,$url) = @_;

    my $tx = $self->prepare_http($url);
    my $context = {};
    $context->{ua} = $self->ua;
    $context->{emitter} = $self;
    $context->{extra_config} = $self;
    $self->ua->start(
        $tx => sub {
            my ($ua,$tx) = @_;
            # process http download failed ,enqueue url to next task
            my $ret = $self->scrape($tx,$res,$context);
        },
    );
}

sub scrape {
    my ($self, $tx, $context) = @_;
    my $res = $tx->res;
    my @ret;

    return unless $res->headers->content_length && $res->body;

    my $base = $tx->req->url;
    my $type = $res->headers->content_type;
    my $pkg = 'Loong::Scraper::'.ucfirst (split('\.',$domain))[0];
    my $method = $tx->req->method;
    my $domain = Mojo::URL->new($base)->ihost;
    $domain =~ s/www.//g;

    eval{
        if ($type && $type =~ qr{^(text|application)/(html|xml|xhtml)}) {
            my $dom = Mojo::DOM->new(decoded_body($res->body));
            require $pkg;
            my $scraper = $pkg->new;
            my $ret = $scraper->index( $method  => $url)->scrape($dom,$context);
        }
    };

    return @ret;
}

sub prepare_http{
    my ($self) = @_;

    $self->emit($_) for qw( cookie ip_pool pre_form);
    my $method = $self->extra_config->{method}||'get';
    my $headers = $self->extra_config->{headers};
    my $form = $self->extra_config->{form};

    $self->ua->transactor->name($self->ua_name);
    $self->ua->max_redirects(5);

    my @args = ($method,$url);
    push (@args,form => $_) if $form;
    push (@args,headers => $_) if $headers;

    return $self->ua->build_tx(@args);
}

sub shuffle{
}

sub clock_speed{
}

1;

