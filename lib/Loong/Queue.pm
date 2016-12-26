package Loong::Queue;

use Loong::Base 'Minion';
use Loong::Mojo::Log;

#my $minion = Minion->new(Pg => 'postgresql://postgres@/test');
has log => sub { Loong::Mojo::Log->new };

sub new {
    my $self = shift->SUPER::new(@_);
    return $self;
}

1;
