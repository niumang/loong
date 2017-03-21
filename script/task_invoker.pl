use lib '../lib';
use Getopt::Long qw(GetOptions);
use Mojo::URL;
use Mojo::Log;
use Pod::Usage qw(pod2usage);
use Parallel::ForkManager;
use Loong::Crawler;
use Carp;

use constant MAX_PROCESS_NUM => 0;

sub single_crawl {
    my $site = shift;
    my $url  = shift;
    $site ||= Mojo::URL->new($url)->ihost;

    my $crawler;
    eval {
        $crawler = Loong::Crawler->new( seed => $site );
        $crawler->log( Mojo::Log->new );
        $crawler->is_debug(1);
        $crawler->beta_crawl($url);
        $crawler->fuck;
    };
    if ($@) {
        Carp::croak
          "可能域名和实际的配置文件不匹配，每一个爬虫都必须配置自己的规则";
    }
}

sub run {
    my ($opts) = @_;

    return single_crawl( $opts->{site}, $opts->{url} ) if $opts->{url};

    Carp::croak '代码执行需要指定一个你要爬取的站名'
      unless $opts->{site};

    my $pool       = $opts->{fork} || MAX_PROCESS_NUM;
    my $max_active = $opts->{max_active};
    my $cache      = $opts->{cache} || 0;
    my $site       = $opts->{site};

    # 防止多进程重复插入任务，首先初始化一把
    my $worker = Loong::Crawler->new( seed => $site );
    $worker->first_blood();

    return $pool
      ? multi_process( $pool, { max_active => $max_active, cache => $cache, site => $site } )
      : $worker->init->fuck;
}

sub multi_process {
    my ( $pool, $opts ) = @_;

    my $site = delete $opts->{site};
    my $pm   = Parallel::ForkManager->new($pool);
  LOOP:
    for my $loop ( 1 .. $pool ) {
        my $pid = $pm->start and next LOOP;
        my $lc = Loong::Crawler->new( seed => $site );
        $lc->init->fuck;
        $pm->finish;
    }
    $pm->wait_all_children;
}

my $man  = 0;
my $help = 0;
my $site;
my $interval;
my $concurrent;
my $fork;
my $url;

pod2usage("$0: 没有参数.") if @ARGV == 0;
my %args = (
    'help'       => $help,
    'man'        => $man,
    'site'       => $site,
    'url'        => $url,
    'max_active' => $active_host,
    'cache'      => $cache,
    'fork'       => $fork,
    'debug'      => $debug,
);
GetOptions( \%args, 'help', 'man', 'site=s', 'url=s', 'max_active=i', 'cache', 'fork=i', 'debug' )
  or die pod2usage(2);
pod2usage(1) if $help;
pod2usage( -verbose => 2 ) if $man;

#pod2usage("$0: 没有参数.") if @ARGV == 0;

run( \%args );

__END__
=encoding utf8

=head1 NAME
 
sample - Using GetOpt::Long and Pod::Usage
 
=head1 SYNOPSIS
 
task_invoker.pl [options] 
 
 Options:
   --help            显示帮助信息
   --man             显示全部文档
   --site            需要抓取的站名
   --max_active      同一个域名异步的最大并发数,默认为10 egg: --max_active 20 
   --fork            开启多进程抓取，默认为单进程模式. egg: --fork 4
   --cache           缓存抓取的网页源文件,默认为0
   --debug           debug模式只抓取单个页面
   --url             debug模式下采集的url


example: 

    cd script;
    # 开4个进程,8个并发
    perl task_invoker.pl --site 91porn.com --fork 4 --max_active 8
    # 单独采集一个页面
    perl task_invoker.pl --debug --url https://nba.hupu.com/teams


 
=head1 OPTIONS
 
=over 4
 
=item B<-help>
 
帮助信息
 
=item B<-man>
 
打印所有文档
 
=back
 
=head1 DESCRIPTION
 
B<This program> will read the given input file(s) and do something
useful with the contents thereof.
 
=cut
