package Loong::Queue::Worker;

use Loong::Base 'Minion::Worker';
use Loong::Queue;
use Loong::Mojo::Log;

has minion => sub { Loong::Queue->new( Pg => 'postgresql://postgres@/test' ) };
has log => sub { Loong::Mojo::Log->new };

sub new{
    my $self = shift->SUPPER::new(@_);
    $self->on('dequeue' => sub { $self->_dequeue(@_) });
    return $self;
}

sub _dequeue{
    my ($self,$job) = @_;

    my $id = $job->id;
    my $args = $job->args;

    my ($task_info) = @$args;
    if( my $task_name = $job->task ){
        $self->emit($task_name,$task_info);
    }
}

1;
__END__


