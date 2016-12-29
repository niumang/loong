package Loong::Scraper::Hhssee;

use Mojo::Base 'Loong::Scraper';
use Loong::Route;
use Mojo::Util qw(dumper);

# http://www.hhssee.com
get 'hhssee.com$' => sub {
    my ($self,$dom,$ctx) = @_;
    my $url = $ctx->{tx}->req->url;
    my $ret = { nexts => [] };

    for my $e($dom->at('div.cHNav')->find('a')->each){
        #/comic/class_1.html
        if($e->{href}=~ m/class_\d+.html/){
            push @{ $ret->{nexts} },{ url => $ctx->{base}.$e->{href} };
        }
    }
    $ret->{url} = $url;
    return $ret;
};

# http://www.hhssee.com/comic/class_4.html
get 'comic/class_\d+.html' =>sub {
    return
};

1;


