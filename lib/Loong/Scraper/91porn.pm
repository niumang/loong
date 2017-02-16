package Loong::Scraper::91porn;

use Loong::Scraper -route;
use Mojo::Util 'url_unescape';
use utf8;

get 'v.php.next=watch$' => sub {
    my ( $self, $dom, $ctx ) = @_;
    my $ret = { data => [], nexts => [] };

    my @nexts;
    my $total = $dom->at('#paging')->find('a')->[-2]->text;
    @nexts =
      map { { url => join( '', $ctx->{base}, '?next=watch&page=', $_ ) } }
      ( 1 .. $total );
    $ret->{nexts} = \@nexts;

    return $ret;
};

get 'page=\d+$' => sub {
    my ( $self, $dom, $ctx ) = @_;
    my $ret = { data => [], nexts => [] };

    for my $channel ( $dom->find('div.listchannel')->each ) {
        my $item = {};
        my $node = $channel->find('a')->[0];

        $item->{topic_img} = $node->at('img')->{src};
        $item->{desc}      = $node->at('img')->{title};
        $item->{url}       = $node->{href};
        push @nexts, $item;
    }

    $ret->{nexts} = \@nexts;
    return $ret;
};

# http://91porn.com/view_video.php?viewkey=9d8bac2a24bc2c7b7452
# http://192.240.120.2/mp43/198333.mp4?st=T94wtkHAv0KWaOegapDkZA&e=1487171450
# Request URL:http://91porn.com/getfile.php?VID=198333&mp4=0&seccode=9d69d3f344ed7bd472ad054304d0bfa9&max_vid=198435
#
get 'view_video.php.viewkey=\S+' => sub {
    my ( $self, $dom, $ctx ) = @_;
    my $ret = { data => [], nexts => [] };

    my $html = "$dom";
    my %matched = $html =~ m/so.addVariable.'(.+?)','(.+?)'./sig;
    my $json_url =
        $ctx->{base}
      . "/getfile.php?VID="
      . $matched{file} . "&mp4="
      . $matched{mp4}
      . "&seccode="
      . $matched{seccode}
      . "&max_vid="
      . $matched{max_vid};

    $ret->{next} = [ { url => $json_url } ];

    return $ret;
};

get 'getfile.php.+\d+$' => sub {
    my ( $self, $dom, $ctx ) = @_;
    my $ret = { data => [], nexts => [] };

    my $html = "$dom";
    if($html=~ m/file=(\S+)/si){
        push @{ $ret->{nexts} }, { url => url_unescape($1) };
    }
    return $ret;
};

1;
