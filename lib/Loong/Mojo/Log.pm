package Loong::Mojo::Log;

use Mojo::Base 'Mojo::Log';
use Loong::Config;
use File::Spec;
use File::Path 'make_path';
use File::Basename;

use constant DEBUG => $ENV{LOONG_DEBUG};
use constant LEVEL => $ENV{LOONG_LOG_LEVEL}||'info';

has config => sub { Loong::Config->new };

sub new {
    my $self = shift->SUPER::new(@_);

    my $app_log = $self->config->app_log || File::Spec->catfile('/tmp/loong.log');
    my $dir = dirname($app_log);
    make_path $dir if not -d $dir;
    $self->path($app_log) unless DEBUG;
    $self->level(LEVEL);
    return $self;
}

1;

__END__
