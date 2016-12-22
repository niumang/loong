package Loong::Scraper::Hhssee;

use Mojo::Base 'Loong::Scraper';
use Loong::Route;

get 'hhssee' => sub {
    my ($dom,$ctx) = @_;
    my $url = $ctx->{tx}->req->url;
    print "Done url => $url\n";
};

1;


