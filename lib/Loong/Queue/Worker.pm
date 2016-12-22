package Loong::Queue::Worker;

use Loong::Base 'Minion::Worker';
use Loong::Queue;
use Loong::Mojo::Log;

has minion => sub { Loong::Queue->new( Pg => 'postgresql://postgres@/test' ); }
has log => sub { Loong::Mojo::Log->new };

sub new{
    my $self = shift->SUPPER::new(@_);

    $self->on('enqueue' => sub { &_enqueue(@_) };
    $self->on('dequeue' => sub { &_dequeue(@_) };

    return $self;
}

sub _dequeue{
    my ($worker,$job) = @_;

    my $id = $job->id;
    my $args = $job->args;

    my ($task_info) = @$args;
    my $task_name = $task_info->{task_name};
    if( my $task_name = $task_info->{task_name} ){
        $self->emit($task_name,$task_info);
    }
}


