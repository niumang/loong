package Loong::Scraper::Hupu;

use Loong::Base 'Loong::Scraper';
use Loong::Route;
use Data::Dumper;

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
    '平均时间' => 'FPG',
};
my $team_mapping = {
};
my $player_terms = {
   '身高' => 'height',
   '位置' => 'pos',
   '体重' => 'weight',
   '生日' => 'birthday',
   '球队' => 'team',
   '学校' => 'school',
   '选秀' => 'draft',
   '国籍' => 'country',
   '本赛季薪金' => 'salary',
   '合同' => 'contract',
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

get 'nba.hupu.com/schedule$' => sub {
    my ($self,$dom,$ctx) = @_;
    my $ret = {};
    my @nexts;

    for my $e( $dom->find('span.team_name')->each ){
        my $item = {
            url => $e->at('a')->{href},
            name => $e->all_text,
        };
        push @nexts,$item;
    }
    $ret->{nexts} = \@nexts;
    return $ret;
};

get '/schedule/\w+$' => sub {
    my ($self,$dom,$ctx) = @_;
    my $ret = {};
    my @nexts;

    my $ht;
    my $url = $ctx->{tx}->req->url;
    if($url=~ m{schedule/\w+$}){
        $ret->{team} = $1;
        #$ret->{zh_team} = $team_mapping->{$1};
    }

    my @schedules;
    for my $tr($dom->find('tr.left')->each){
        my $text = $tr->all_text;
        my $item;
        if($text=~ m/胜|负/){
            if($text=~ m{
                    (\S+)\s+vs\s+(\S+).*? # 马刺 vs 太阳
                    (\d+)\s+-\s+(\d+).*? # 86 - 91
                    (胜|负).*? # 负
                    (\d+-\d+-\d+\s+\d+:\d+:\d+) # 2016-10-04 10:00:00
                }sx
            ){
                $item->{away} = $1;
                $item->{home} = $2;
                $item->{away_score} = $3;
                $item->{home_score} = $4;
                $item->{result} = $5;
                $item->{play_time} = $6;
                push @schedules,$item;
            }
        }
    }
    $ret->{schedule} = \@schedules;
    return $ret;
};

get 'nba.hupu.com/teams/\w+' => sub {
    my ( $self, $dom, $ctx ) = @_;
    my $ret = {};
    my @nexts;

    my $team = $dom->at('div.table_team_box')->all_text;
    if($team=~ m/(场均失分).*?([\d\.]+)/s){
        $ret->{ $nba_terms->{$1} } = $2;
    }
    for my $e($dom->at('div.jiben_title_table')->find('a')->each){
        push @nexts,{
            url => $e->{href},
            title => $e->{title},
        };
    }
    $ret->{home} =~ s/'//g;
    $ret->{home} =~ s/\s+$//g;
    $ret->{home} =~ s/^s+//g;
    $ret->{nexts} = \@nexts;
    _parse_nba_pro_terms($dom,$ret);
    return $ret;
};

get 'nba.hupu.com/players/.+html' => sub {
    my ($self,$dom,$ctx) = @_;
    my $ret = {};
    _parse_nba_pro_terms($dom,$ret);
    return $ret;
};

sub _parse_nba_pro_terms{
    my ($dom,$ret) = @_;

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
        $ret->{home} =~ s/'//g;
        $ret->{home} =~ s/\s+$//g;
        $ret->{home} =~ s/^s+//g;
        $ret->{zone} =~ s/\n//g;
    }
    my %player_info = $content =~ m{
        (位置)：(\S+).*?  #(位置)：F（7号）.*?
        (身高)：(\S+).*?  #(身高)：2.03米/6尺8.*?
        (体重)：(\S+).*?  #(体重)：109公斤/240磅.*?
        (生日)：([\d-]+).*?  #(生日)：1984-05-29.*?
        (球队)：(\S+).*?  #(球队)：纽约尼克斯.*?
        (学校)：(\S+).*?  #(学校)：雪城大学.*?
        (选秀)：(\S+).*?  #(选秀)：2003年第1轮第3顺位.*?
        (国籍)：(\S+).*?  #(国籍)：美国.*?
        (本赛季薪金)：(\S+).*?  #(本赛季薪金)：2456万美元.*?
        (合同)：(\S+) #(合同)：5年1.24亿美元，2014年夏天签，2019年夏天到期，2018夏提前终止合同选项；拥有交易否决权；合同包含15%交易保证金\s+
    }sxi;
    if($player_info{'生日'}){
        $ret->{$player_terms->{$_}} = $player_info{$_} for keys %player_info;
    }
    for my $item($dom->at('div.team_qushi')->find('a')->each){
        #得分变化趋势图    平均得分： 105.4 分
        my $text = $item->{tit};
        if($text=~ m{(\S+)：.*?([\d\.]+)}six){
            my $term = $nba_terms->{$1};
            $ret->{$term} = $2;
        }
    }
}

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


