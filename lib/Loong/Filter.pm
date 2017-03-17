package Loong::Filter;

use Loong::Base -base;
use Mojo::URL;
use Redis;

has redis => sub { Redis->new };

sub is_crawled {
    my ( $self, $url ) = @_;
    my $host = Mojo::URL->new($url)->ihost;

    return 0 unless $self->redis->pfcount( $host, $url );
    my $rv = !$self->_add($url);
    $rv ||= 0;
    return $rv;
}

sub _add {
    my ( $self, $url ) = @_;
    my $host = Mojo::URL->new($url)->ihost;
    return $self->redis->pfadd( $host, $url );
}

sub crawled {
    return shift->_add(shift);
}

1;

__END__
