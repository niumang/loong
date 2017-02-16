package Loong::Mojo::UserAgent;

use Mojo::Base 'Mojo::UserAgent';
use Mojo::URL;
use Mojo::File 'path';
use Env qw(HOME);
use File::Spec;
use List::Util 'first';
use YAML qw(LoadFile DumpFile Dump);

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
    my ($domain,$ihost);
    $domain = $ihost = $tx->req->url->ihost;
    $domain=~ s/www.//g;
    my $cookie_file = File::Spec->catfile($self->cookie_path,$domain);
    my $cookie_jar;

    warn "dumper cookie_file= $cookie_file\n";
    # 如果cookie为空，调用cookie生产脚本,并且加载cookiejar
    if(-e $cookie_file){
        my $load = LoadFile($cookie_file);
        $cookie_jar = $self->rand_cookie($load);

        warn("获取rand cookie从文件: ".Dump($cookie_jar));
        my $first = first { $_->{expires} } @{ $cookie_jar->{jar}->{$ihost} };
        my $now = time;
        my $expires = $first->{expires}||0;
        $cookie_jar = $self->_reload_cookie($cookie_file) if( !defined $first || $now > $expires)
    }else{
        $cookie_jar = $self->_reload_cookie($cookie_file);
    }

    $self->cookie_jar($cookie_jar);
}

sub _reload_cookie{
    my ($self,$cookie_file) = @_;

    my $cmd;
    my $exe='perl';

    $exe = 'python' if $self->cookie_script=~ m/py$/;
    $exe = 'php' if $self->cookie_script=~ m/php$/;
    $exe = 'ruby' if $self->cookie_script=~ m/ruby$/;
    $cmd = join(' ',$exe,$self->cookie_script);
    chmod 0755,$self->cookie_script;
    warn "$cmd\n";
    system($cmd);
    return $self->rand_cookie(LoadFile($cookie_file));
}

sub rand_cookie{
    my ($self,$data) = @_;
    my @cookies = @{ $data };
    return $cookies[int(rand @cookies)];
}

1;

