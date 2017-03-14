use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojo::Base -strict;
use Test::More;
use Loong::Crawler;

my $url = shift;
my $loong = Loong::Crawler->new( seed => 'www.hupu.com' );
$url ? $loong->beta_crawl($url) : $loong->init;
$loong->fuck;

done_testing();
