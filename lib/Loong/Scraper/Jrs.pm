package Loong::Scraper::Jrs;

use Loong::Scraper -route;
use Mojo::DOM;
use Data::Dumper;
use Encode qw(decode_utf8);

# 拿到比赛js
get 'body.html' => sub {
    my ($self, $dom, $ctx) = @_;
    my $url   = $ctx->{url};
    my $ret   = {};
    my @nexts = ();

    my $js = $dom->at('div.game-container-inner > script')->attr('src');
    push @nexts, {url => $js};
    $ret->{nexts} = \@nexts;
    return $ret;
};

# 比赛时刻
get 'js/\d+.js' => sub {
    my ($self, $dom, $ctx) = @_;
    my $js = "$dom";
    my @nexts;
    my $ret = {data => [], nexts => [], collection => 'topic'};

    # document.write("<html>");
    my ($html) = $js =~ m{\(\"(.*?)\"\)}si;
    $html =~ s/\\//g;
    $dom = Mojo::DOM->new(decode_utf8($html));
    for my $li ($dom->find('li[class="game-item "]')->each) {
        my $item = {};
        my $divs = $li->find('div');

        $item->{url}  = $li->at('a')->{href};
        $item->{desc} = $divs->[0]->at('font')->text;
        $item->{time} = $divs->[1]->all_text;
        $item->{time} =~ s/^\s+//g;
        $item->{time} =~ s/\s+$//g;
        $item->{home} = $divs->[2]->all_text;
        $item->{home} =~ s/^\s+//g;
        $item->{home} =~ s/\s+$//g;
        $item->{home_logo} = $divs->[2]->at('img')->{src};
        $item->{away}      = $divs->[4]->all_text;
        $item->{away} =~ s/^\s+//g;
        $item->{away} =~ s/\s+$//g;
        $item->{away_logo} = $divs->[4]->at('img')->{src};
        push @{$ret->{data}}, $item if $item->{desc} =~ m/nba/i;
    }

    $ret->{nexts} = \@nexts;
    return $ret;
};

# href="http://nba.tmiaoo.com/n/100209400?classid=1&id=1297"
# 直播链接
# http://nba.tmiaoo.com/n/100209400/p.html
get '(classid=\d+.id=\d+)$' => sub {
    my ($self, $dom, $ctx) = @_;
    my $ret = {data => [], nexts => []};

    my $url = $ctx->{tx}->req->url->to_string;

    #http://nba.tmiaoo.com/n/100209400?classid=1&id=1422
    if ($url =~ m{n/(\d+)\?}) {
        push @{$ret->{nexts}}, 'http://nba.tmiaoo.com/n/' . $1 . '/p.html';
    }

    return $ret;
};

get '\d+/p.html' => sub {
    my ($self, $dom, $ctx) = @_;
    my $ret = {data => [], collection => 'live'};
    for my $e ($dom->at('div.mv_action')->find('a')->each) {
        my $item = {};
        $item->{live_url} = $e->{href};
        $item->{title}    = $e->text;
        push @{$ret->{data}}, $item;
    }

    return $ret;
};

1;

