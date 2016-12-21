package Loong::Mojo:: -serAgent;

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
    state $well_known_ports = { http => 80, https => 443 };
    my $url = shift;
    $url = Mojo::URL->new($url) unless ref $url;
    return
      unless $url->is_abs && ( my $wkp = $well_known_ports->{ $url->scheme } );
    my $key = $url->scheme . '://' . $url->ihost;
    return $key unless ( my $port = $url->port );
    $key .= ':' . $port if $port != $wkp;
    return $key;
}

1;

