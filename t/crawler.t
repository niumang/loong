use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojo::Base -strict;
use Test::More;
use Loong::Crawler;
use Loong::Scraper::Hhssee;

my $loong = Loong::Crawler->new(seed => 'caoliu.com');
$loong->beta_crawl('http://cc.swqu.org/htm_data/15/1612/2197156.html');
$loong->fuck;

done_testing();
