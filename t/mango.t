use lib '../lib';
use Loong::Mango;
use Loong::Config;
use YAML qw(Dump);

my $config = Loong::Config->new;
my $mango  = Loong::Mango->new($config->mango_uri);

my $collection = $mango->db('hupu')->collection('counter');

my $teams = $collection->find_one({url => qr{nba.hupu.com/teams}});
print Dump $teams;
exit;

my @team_meta = qw(
  name logo zone union win los coach site home zh_name
);

for my $item (@{$teams->{nexts}}) {

=pod
  - los: 26
    name: 热火
    url: https://nba.hupu.com/teams/heat
    win: 11

=cut

    my $team = {
        logo    => $item->{logo},
        zh_name => $item->{zh_name},
        win     => $item->{win},
        los     => $item->{los},
        name    => $item->{name},
    };
    my $players = delete $item->{nexts};
    my $team_info = $collection->find_one({url => $item->{url}});

    $team->{coach} = delete $team_info->{coach};
    $team->{home}  = delete $team_info->{home};
    $team->{zone}  = delete $team_info->{zone};
    $team->{site}  = delete $team_info->{site};
    $team->{born}  = delete $team_info->{born};

    my $players   = delete $team_info->{nexts};
    my $team_stat = $team_info;
    $team_stat->{name} = $item->{name};
    print "team_stat -=---------------------" . Dump($team_stat);
    print "team -=---------------------" . Dump($team);
    my $schedule_url = 'https://nba.hupu.com/schedule/' . $item->{name};

    # https://nba.hupu.com/schedule/rockets
    my $find = $collection->find_one({url => $schedule_url});
    print Dump $find;
    for my $schedule (@{$find->{schedule}}) {
        next unless $schedule;
        $schedule->{team} = $item->{name};
        print "schedule -----" . Dump($schedule);
        exit;
    }
    exit;
}


#https://nba.hupu.com/teams


