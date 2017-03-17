use lib '../lib';
use Test::More;
use Loong::Filter;

my $f    = Loong::Filter->new;
my $time = time;
my @urls = map { "http://example.com/$time$_" } ( 1 .. 20 );

is( $f->is_crawled($_), 0, "第一次应该是没有爬到过的随机连接 : $_" ) for @urls;
$f->crawled($_) for @urls;
is( $f->is_crawled($_), 1, "爬过了 : $_" ) for @urls;
done_testing;

