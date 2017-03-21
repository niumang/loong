package Loong::Lite;

use Mojo::Util qw(monkey_patch);
use Mojo::URL;
use Mojo::UserAgent;
use File::Spec;

use Loong::Scraper;

my $scraper;

sub import {
    my $class  = shift;
    my $caller = caller;
    no strict 'refs';
    push @{"${caller}::ISA"}, 'Loong::Scraper';

    for my $method (qw(get post put delete)) {
        monkey_patch $caller => $method => sub {
            my ( $url_pattern, $cb ) = ( shift, pop );
            my ( $headers, %attr );
            $headers = shift if @_ == 1;
            %attr    = @_    if @_ == 2;
            ( $headers, %attr ) = @_ if @_ == 3;

            my $key = join( '|', $method, $url_pattern );
            $scraper->{$key}->{method}  = $method;
            $scraper->{$key}->{cb}      = $cb;
            $scraper->{$key}->{headers} = $headers if ref $headers;
            $scraper->{$key}->{form}    = $attr{form} if ref $attr{form};
            return $scraper;
        };
    }

    monkey_patch $caller => scraper_opts => sub {
        return $scraper;
    };
    monkey_patch $caller => run => sub {
        my $url  = shift;
        my $opts = shift;
        my $s    = Loong::Scraper->new( domain => $url );
        my $matched = $s->match( $url, $scraper );
        my @args;
        my ( $method, $headers, $form ) = ( map { $matched->{$_} } qw(method headers form) );
        push @args, $headers if $headers;
        push @args, ( form => $form ) if $form;
        my $tx = Mojo::UserAgent->new->max_redirects(5)->$method( $url => @args );
        $s->scrape( $url, $tx->res, $opts );
    };
    monkey_patch $caller => download => sub {
        my $url        = shift;
        my $target_dir = shift;

        die "请指定下载的目录" unless -e $target_dir;

        my $file_name = ( split( /\//, $url ) )[-1];
        my $path = File::Spec->catfile( $target_dir, $file_name );
        print "Download $url => $path\n";
        Mojo::UserAgent->new->get($url)->res->content->asset->move_to($path);
    };
}

1;
