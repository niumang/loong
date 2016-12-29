package Loong::Scraper;

use Mojo::Base -base;
use Data::Dumper;

has key => 0;
has method => 'get';
has domain => '';

sub scrape{
    my $self = shift;
    Carp::croak "invalid url_pattern " unless $self->key;
    return $self->scraper->{$self->key}->{$self->method}->{cb}->($self,@_);
}

1;

__END__
