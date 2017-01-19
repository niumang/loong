package Loong::Scraper::Hupu;

use Loong::Base 'Loong::Scraper';
use Loong::Route;
use Data::Dumper;
use Encode qw(decode_utf8);

my $nba_terms = {
    '平均得分'             => 'PPG',
    '场均失分'             => 'LPG',
    '平均出手数'          => 'FGA',
    '平均命中率'          => 'FGP',
    '平均3分得分'         => '3PM',
    '平均3分出手数'      => '3PA',
    '平均3分命中率'      => '3PP',
    '平均罚球出手数'    => 'FTA',
    '平均罚球命中次数' => 'FTM',
    '平均罚球命中率'    => 'FTP',
    '平均防守篮板'       => 'DEFR',
    '平均进攻篮板'       => 'OFFR',
    '平均篮板球数'       => 'RPG',
    '平均助攻'             => 'APG',
    '平均抢断'             => 'SPG',
    '平均盖帽'             => 'BPG',
    '平均失误'             => 'TPG',
    '平均犯规'             => 'FPG',
    '平均时间'             => 'MIN',
};
my $team_mapping = {};
my $player_terms = {
    '身高'          => 'height',
    '位置'          => 'pos',
    '体重'          => 'weight',
    '生日'          => 'birthday',
    '球队'          => 'zh_team',
    '学校'          => 'school',
    '选秀'          => 'draft',
    '国籍'          => 'country',
    '本赛季薪金' => 'salary',
    '合同'          => 'contract',
};

# https://nba.hupu.com/teams
get 'hupu.com/teams$' => sub {
    my ($self, $dom, $ctx) = @_;
    my $url = $ctx->{url};
    my $ret = {data => [], nexts => [], collection => 'teams'};

    my $game = $dom->at('div.gamecenter_content');
    my @nexts;
    my @data;
    for my $team ($game->find('a.a_teamlink')->each) {
        my $item = {};
        ($item->{win}, $item->{los}) = $team->at('p')->text =~ m/(\d+).(\d+)/;
        $item->{url} = $team->attr('href');
        ($item->{name}) = $item->{url} =~ m{/(\w+)$};
        $item->{logo}    = $team->at('img')->{src};
        $item->{zh_name} = $team->at('h2')->text;
        push @nexts, $item;
        push @data,  $item;
    }
    $ret->{nexts} = \@nexts;
    $ret->{data}  = \@data;
    return $ret;
};

get 'nba.hupu.com/schedule$' => sub {
    my ($self, $dom, $ctx) = @_;
    my $ret = {data => [], nexts => [], collection => 'schedule'};
    my @nexts;

    for my $e ($dom->find('span.team_name')->each) {
        my $item = {
            url  => $e->at('a')->{href},
            name => $e->all_text,
        };
        push @nexts, $item;
    }
    $ret->{nexts} = \@nexts;
    return $ret;
};

get '/schedule/\w+$' => sub {
    my ($self, $dom, $ctx) = @_;
    my $ret = {data => [], nexts => [], collection => 'schedule'};
    my @nexts;

    my $ht;
    my $url = $ctx->{tx}->req->url;
    my $team;
    if ("$url" =~ m{schedule/(\w+)$}) {
        $team = $1;
    }

    my @schedules;
    for my $tr ($dom->find('tr.left')->each) {
        my $text = $tr->all_text;
        my $item;
        if ($text =~ m{
                (\S+)\s+vs\s+(\S+).*? # 马刺 vs 太阳
                (\d+|)\s+-\s+(\d+|).*? # 86 - 91
                (\d+-\d+-\d+\s+\d+:\d+:\d+) # 2016-10-04 10:00:00
            }sx
          )
        {
            $item->{away}       = $1;
            $item->{home}       = $2;
            $item->{away_score} = $3;
            $item->{home_score} = $4;
            $item->{play_time}  = $5;
            $item->{team}       = $team;
            $item->{url}        = "$url";
        }
        if ($text =~ m/(胜|负)/) {
            $item->{result} = $1;
        }
        push @schedules, $item if $item;
    }
    $ret->{data} = \@schedules;
    return $ret;
};

get 'nba.hupu.com/teams/\w+' => sub {
    my ($self, $dom, $ctx) = @_;
    my $ret = {data => [], nexts => [], collection => 'team_stat'};

    my $url = $ctx->{tx}->req->url;
    my @nexts;

    my $data_ref;
    my $team = $dom->at('div.table_team_box')->all_text;
    if ($team =~ m/(场均失分).*?([\d\.]+)/s) {
        $data_ref->{$nba_terms->{$1}} = $2;
    }
    _parse_nba_pro_terms($dom, $data_ref);
    for my $e ($dom->at('div.jiben_title_table')->find('a')->each) {
        push @nexts, {url => $e->{href}, title => $e->{title},};
    }
    $data_ref->{home} =~ s/'//g;
    $data_ref->{home} =~ s/\s+$//g;
    $data_ref->{home} =~ s/^s+//g;
    $data_ref->{url} = "$url";
    $ret->{nexts}    = \@nexts;
    $ret->{data}     = [$data_ref];

    return $ret;
};

get 'nba.hupu.com/players/.+html' => sub {
    my ($self, $dom, $ctx) = @_;
    my $ret  = {data => [], nexts => [], collection => 'player'};
    my $data = {};
    my $url  = $ctx->{tx}->req->url;
    $data->{url}     = "$url";
    $data->{name}    = $dom->at('div.team_data')->find('h2')->[0]->text;
    $data->{profile} = $dom->at('div.team_data')->find('img')->first->{src};

    # 泰勒-恩尼斯（Tyler Ennis）
    if ($data->{name} =~ m{(\S+?)（(.*?)）}s) {
        $data->{name}    = $2;
        $data->{zh_name} = $1;
    }
    _parse_nba_pro_terms($dom, $data);
    $ret->{data} = [$data];
    return $ret;
};

sub _parse_nba_pro_terms {
    my ($dom, $ret) = @_;

    my $content = $dom->at('div.content_a')->all_text;
    my $team    = $dom->at('div.table_team_box')->all_text;
    if ($team =~ m/(场均失分).*?([\d\.]+)/s) {
        $ret->{$nba_terms->{$1}} = $2;
    }
    if ($content =~ m{
        进入NBA：(\d+)年.*? # 进入NBA：1976年
        主场：(.*?) 分区：(.*?) # 主场：AT&T 中心 分区：西南赛区
        官网：(\S+).*?    # 官网：http://www.nba.com/spurs/
        主教练：(\S+) # 格雷格-波波维奇
    }sxi
      )
    {
        $ret->{born}  = $1;
        $ret->{home}  = $2;
        $ret->{zone}  = $3;
        $ret->{site}  = $4;
        $ret->{coach} = $5;
        $ret->{home} =~ s/'//g;
        $ret->{home} =~ s/\s+$//g;
        $ret->{home} =~ s/^s+//g;
        $ret->{zone} =~ s/\n//g;
    }

=pod
位置：G（8号）
身高：1.88米/6尺2
体重：79公斤/175磅
生日：1984-09-24
球队：休斯顿火箭
学校：Cal State Fullerton
国籍：美国
本赛季薪金：98万美元
合同：1年98万美元，2016年夏天签，2017年夏天到期，2016-17赛季无保障
=cut

    my $player_info = {};
    my $node        = $dom->at('div.team_data > div > div.content_a > div > div.font');
    for my $p ($node->find('p')->each) {
        if ($p->all_text =~ m/(\S+)：(.*)/) {
            $ret->{$player_terms->{$1}} = $2 if $player_terms->{$1};
        }
    }
    if ("$node" =~ m{teams/(\w+)}) {
        $ret->{team} = $1;
    }
    for my $item ($dom->at('div.team_qushi')->find('a')->each) {
        my $text = $item->{tit};

        #得分变化趋势图    平均得分： 105.4 分
        if ($text =~ m{(\S+)：.*?([\d\.]+)}six) {
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

CREATE TABLE `schedule` (
  `id` int(20) ,
    `match_time` datetime,
  `home` varchar(20),
    `away` varchar(20),
    `home_score` int(11),
    `away_score` int(11),
    `result` varchar(10),
    `stat` text,
    `video` varchar(255),
    `highlight` varchar(255)
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `zhibo` (
  `id` int(20) ,
    tv_date datetime,
  home varchar(20),
    away varchar(20),
    play_url text
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


