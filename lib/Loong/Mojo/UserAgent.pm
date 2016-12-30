package Loong::Mojo::UserAgent;

use Mojo::Base 'Mojo::UserAgent';
use Mojo::URL;

has active_conn => 0;
has active_conn_per_host => sub { {} };

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->on(
        start => sub {
            my ( $self, $tx ) = @_;
            my $url = $tx->req->url;
            $self->active_host( $url, 1 );
            $tx->on( finish => sub { $self->active_host( $url, -1 ) } );
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

1;

