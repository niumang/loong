package Loong::Scraper::Jrs;

use Loong::Base 'Loong::Scraper';
use Loong::Route;
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
    my $ret = {};

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
        push @nexts, $item if $item->{desc} =~ m/NBA常规赛/;
    }

    $ret->{nexts} = \@nexts;
    return $ret;
};

# href="http://nba.tmiaoo.com/n/100209400?classid=1&id=1297"
# 直播链接
# http://nba.tmiaoo.com/n/100209400/p.html
get '(classid=\d+.id=\d+|\d+/p.html)$' => sub {
    my ($self, $dom, $ctx) = @_;
    my $ret = {};

    my @play_list;
    for my $e ($dom->find('div.mv_action')->each) {
        push @play_list,
          { url  => $e->at('a')->{href},
            name => $e->at('a')->text,
          };
    }
    $ret->{play_list} = \@play_list;
    return $ret;
};

1;

