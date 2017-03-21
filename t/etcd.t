use lib '../lib';
use Test::More;
use Loong::Config::Etcd;

require_ok('Loong::Config::Etcd');

my $etcd = Loong::Config::Etcd->new;

$etcd->set( 'foo' => { a => 1, b => 3 } );
is_deeply( $etcd->get('foo'), { a => 1, b => 3 }, '测试etcd key=value' );

done_testing();
