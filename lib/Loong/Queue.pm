package Loong::Queue;

use Loong::Base 'Minion';
use Loong::Mojo::Log;

#my $minion = Minion->new(Pg => 'postgresql://postgres@/test');
has log => sub { Loong::Mojo::Log->new };

sub new {
    my $self = shift->SUPER::new(@_);
    return $self;
}

sub _update_task_status{
    my ($self,$job,$status,$message) = @_;
    return unless ref($job) =~ m/job/i;
    $job->$status($message);
}

sub update_failed_task{
    my ($self,$job,$message) = @_;
    $self->_update_task_status($job,'fail',$message);
}

sub finished_task{
    my ($self,$job,$message) = @_;
    $self->_update_task_status($job,'finish',$message);
}

1;
