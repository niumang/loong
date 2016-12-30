package Loong::Route;

use File::Basename qw(basename dirname);
use Mojo::Base -base;
use Mojo::URL;
use Mojo::Util 'monkey_patch';
use Data::Dumper;

use constant DEBUG => $ENV{LOONG_DEBUG} || 0;

my $config;

sub import{
    $ENV{LOONG_EXE} ||= (caller)[1];

    my $caller = caller;
    no strict 'refs';

    my $scraper = {};
    for my $name(qw(get post put delete)){
        monkey_patch $caller =>  $name =>  sub {
            my $url_pattern = shift;
            my $cb = pop;
            my $headers = shift;
            $scraper->{$url_pattern}->{$name} = { method => $name, cb => $cb, headers => $headers };
        };
    }
    monkey_patch $caller => 'scraper' => sub {
        my $self = shift;
        return $scraper;
    };
    monkey_patch $caller, 'find' => sub {
        my ($self,$method,$url) = @_;
        my $host = Mojo::URL->new($url)->host;
        my ($key) = grep { $url=~ m/$_/ } keys %$scraper;
        $self->key($key);
        $self->method($method);
        return $self;
    };
    Mojo::Base->import($_) for qw(-strict Mojo::DOM Mojo::URL Mojo::UserAgent Mojo::Log);
}

1;


__END__





