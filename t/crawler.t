use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojo::Base -strict;
use Test::More;
use Loong::Crawler;
use Loong::Scraper::Hhssee;

my $loong = Loong::Crawler->new(seed => 'hhssee.com');
$loong->init;
$loong->fuck;

done_testing();
