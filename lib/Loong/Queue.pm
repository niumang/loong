package Loong::Queue;

use Loong::Base 'Minion';
use Loong::Mojo::Log;

#my $minion = Minion->new(Pg => 'postgresql://postgres@/test');
has log => sub { Loong::Mojo::Log->new };

sub new {
    my $self = shift->SUPPER::new(@_);

    $self->on('enqueue' => sub { _enqueue(@_) });
    $self->on('dequeue' => sub { _enqueue(@_) });
}

sub _enqueue{
}

1;
