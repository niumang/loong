package Loong::Mojo::UserAgent;

use Mojo::Base 'Mojo::UserAgent';
use Mojo::URL;
use Mojo::File 'path';
use Env qw(HOME);
use File::Spec;
use List::Util 'first';
use YAML qw(LoadFile DumpFile);

use constant DEBUG => $ENV{LOONG_DEBUG};

has active_conn => 0;
has active_conn_per_host => sub { {} };
has cookie_path => sub { File::Spec->catdir($HOME,'.cookie') };
has 'cookie_script';

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    path($self->cookie_path)->make_path unless -d $self->cookie_path;

    $self->on( start => sub {
            my ( $self, $tx ) = @_;
            my $url = $tx->req->url;
            $self->active_host( $url, 1 );
            $tx->on( finish => sub {
                    $self->cache_cookie($tx) if $self->cookie_script;
                    $self->active_host( $url, -1 ) }
            );
        }
    );

    return $self;
}

sub active_host {
    my ( $self, $url, $inc ) = @_;
    my $key   = _host_key($url);
    my $hosts = $self->active_conn_per_host;
    if ($inc) {
        $self->{active_conn} += $inc;
        $hosts->{$key} += $inc;
        delete( $hosts->{$key} ) unless ( $hosts->{$key} );
    }
    return $hosts->{$key} || 0;
}

sub _host_key {
    my $url = shift;
    $url='http://'.$url unless $url=~ m/http/;
    $url = Mojo::URL->new($url) unless ref($url);
    my $key = $url->scheme . '://' . $url->ihost;
    return $key;
}

sub cache_cookie{
    my ($self,$tx) = @_;

    my $now = time;
    my $domain = $tx->req->url->ihost;
    $domain=~ s/www.//g;
    my $cookie_file = File::Spec->catfile($self->cookie_path,$domain);
    my $is_expired;

    warn "cache cookie here $cookie_file\n";
    return DumpFile($cookie_file,$self->cookie_jar) if DEBUG;

    if(-e $cookie_file and -s $cookie_file){
        my $cookie_jar = LoadFile($cookie_file);
        warn "read cookie form => $cookie_file\n";
        my $first = first { $_->{expires} } @{ $cookie_jar->{jar}->{$domain} };
        # 如果cookie为空，调用cookie生产脚本,并且加载cookiejar
        my $expires = $first->{expires}||0;
        if( !defined $first || $now > $expires){
            system($self->cookie_script);
            return $self->cookie_jar( LoadFile($cookie_file) );
        }
        return $self->cookie_jar($cookie_jar);
    }
    DumpFile($cookie_file,$self->cookie_jar);
}

1;

