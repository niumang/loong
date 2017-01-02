package Loong;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::Minion;
use Mojo::Log;
use Loong::Config;
use Loong::Mapping;
use Loong::Worker::Crawler;
use Loong::UserAgent;
use Loong::Crawler;
use Loong::Worker::Loader;

has config  => sub { Loong::Config->new };
has mapping => sub { Loong::Mapping->new };
has crawler => sub { Loong::Crawler->new };
has url     => sub { Mojo::URL->new($_[0]) };
has minion  => sub { Mojo::Minion->new };
has log     => sub { Mojo::Log->new };
has ua      => sub {Loong::UserAgent};

my $active   = 0;
my $max_conn = 10;
my $xxx      = 0;

sub new {
    my $self = shift->SUPER::new(@_);
}

sub invoke_task {
    my ($self, $seed) = @_;

    Mojo::IOLoop->recurring(
        0 => sub {
            for ($active + 1 .. $max_conn) {
                my $item = $worker->register->dequeue(0, queue => $seed);
                return ($active or Mojo::IOLoop->stop)
                  if !ref($item) || !$item->{url};

                ++$active;
                my $gc = Loong::Crawler->new(
                    active       => $active,
                    url          => $item->{url},
                    extra_config => {%$item, %{$self->config->{$seed}}}
                );
                $gc->run;
            }
        }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub fuck {
}

1;


