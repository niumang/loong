package Loong::Scraper::Caoliu;

use Loong::Scraper -route;
use utf8;

get '/htm_data/\d+/\d+/\d+.html' => sub {
    my ( $self, $dom, $ctx ) = @_;

    my $tip_top = $dom->at('table > tbody > tr > td > h4');
    my $ret = { next => [], data => {} };
    if ( "$tip_top" =~ m{^.\w+/\d+MB.(\w+-\d+)\s*.+?\[\S+\]\[\S+\]} ) {
        my $fanhao = $1;
        warn "fanhao is $fanhao\n";
    }
    return {};
};

1;
