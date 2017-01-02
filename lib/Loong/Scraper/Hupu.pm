package Loong::Scraper::Hupu;

use Loong::Base 'Loong::Scraper';
use Loong::Route;

my $nba_terms = {
    '平均得分' => 'PPG',
    '场均失分' => 'LPG',
    '平均出手数' => 'FGA',
    '平均命中率' => 'FG%',
    '平均3分得分' => '3PM',
    '平均3分出手数' => '3PA',
    '平均3分命中率' => '3P%',
    '平均罚球出手数' => 'FTA',
    '平均罚球命中次数' => 'FTM',
    '平均罚球命中率' => 'FT%',
    '平均防守篮板' => 'DEFR',
    '平均进攻篮板' => 'OFFR',
    '平均篮板球数' => 'RPG',
    '平均助攻' => 'APG',
    '平均抢断' => 'SPG',
    '平均盖帽' => 'BPG',
    '平均失误' => 'TPG',
    '平均犯规' => 'FPG',
};

# https://nba.hupu.com/teams
get 'hupu.com/teams$' => sub {
    my ($self,$dom,$ctx) = @_;
    my $url = $ctx->{url};
    my $ret = {};

    my $game = $dom->at('div.gamecenter_content');
    my @nexts;
    for my $team( $game->find('a.a_teamlink')->each ){
        my $item = {};
        ($item->{win},$item->{los}) = $team->at('p')->text=~ m/(\d+).(\d+)/;
        $item->{url} = $team->attr('href');
        $item->{name} = $team->at('h2')->text;
        push @nexts,$item;
    }
    $ret->{nexts} = \@nexts;
    return $ret;
};

get 'nba.hupu.com/teams/\w+' => sub {
    my ( $self, $dom, $ctx ) = @_;
    my $ret = {};
    my @nexts;

    my $content  = $dom->at('div.content_a')->all_text;
    my $team = $dom->at('div.table_team_box')->all_text;
    if($team=~ m/(场均失分).*?([\d\.]+)/s){
        $ret->{ $nba_terms->{$1} } = $2;
    }
    if($content =~ m{
        进入NBA：(\d+)年.*? # 进入NBA：1976年
        主场：(.*?) 分区：(.*?) # 主场：AT&T 中心 分区：西南赛区
        官网：(\S+).*?    # 官网：http://www.nba.com/spurs/
        主教练：(\S+) # 格雷格-波波维奇
    }sxi){
        $ret->{born} = $1;
        $ret->{home} = $2;
        $ret->{zone} = $3;
        $ret->{site} = $4;
        $ret->{coach} = $5;
    }

    for my $item($dom->at('div.team_qushi')->find('a')->each){
        #得分变化趋势图    平均得分： 105.4 分
        my $text = $item->{tit};
        if($text=~ m{(\S+)：.*?([\d\.]+)}six){
            my $term = $nba_terms->{$1};
            $ret->{$term} = $2;
        }
    }

    for my $e($dom->at('div.jiben_title_table')->find('a')->each){
        push @nexts,{
            url => $e->{href},
            title => $e->{title},
        };
    }
    $ret->{nexts} = \@nexts;
    return $ret;
};

1;

__DATA__
GP: Games played
GS: Games started
MIN: Minutes per game
FGM: Field Goals Made per game
FGA: Field Goals Attempted per game
FG%: Field Goals Percentage per game
PPG: Points per game
OFFR: Offensive Rebounds per game
DEFR: Defensive Rebounds per game
3PM: Three-point Field Goals Made per game
3PA: Three-point Field Goals Attempted per game
3P%: Three-point Field Goals Percentage per game
RPG: Rebounds per game
APG: Assists per game
SPG: Steals per game
FTM: Free Throws Made per game
FTA: Free Throws Attempted per game
FT%: Free Throws Percentage per game
BPG: Blocks per game
TPG: Turnovers per game
FPG: Fouls per game
2PM: Two-point Field Goals Made per game
2PA: Two-point Field Goals Attempted per game
2P%: Two-point Field Goals Percentage per game

A/TO: Assist to turnover ratio
PER: Player Efficiency Rating
PPS: Points Per Shot per game
AFG%: Adjusted Field Goal Percentage per game


