use lib '../lib';
use YAML qw(Dump);
use Loong::Loader;

my $loader = Loong::Loader->new( site => 'hupu.com' );

$loader->transfer_data;

