use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojo::Base -strict;
use Test::More;
use Loong::Crawler;
use Loong::Scraper::Hhssee;

my $loong = Loong::Crawler->new();

$loong->crawl('http://www.hhssee.com');

done_testing();
