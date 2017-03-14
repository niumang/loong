use lib '../lib';
use Loong::DB::MySQL;
use Data::Dumper;
use Test::More;

my $uri = 'mysql://root:root@127.0.0.1/nba';

my $mysql = Loong::DB::MySQL->new($uri);
$mysql->db->query('DROP TABLE IF EXISTS `names`');
$mysql->db->query('create table names (id integer auto_increment primary key, name text)');

$mysql->insert( 'names', { name => 'james' } );
my $hash = $mysql->select( 'names', ['name'], { name => 'james' } )->hash;
is( $hash->{name}, 'james', 'test insert names result ok' );
$mysql->update( 'names', { name => 'fuck' }, { name => 'james' } );
$hash = $mysql->select( 'names', ['name'], { name => 'fuck' } )->hash;
is( $hash->{name}, 'fuck', 'test update names result ok' );
$mysql->delete( 'names', { name => 'fuck' } );
$hash = $mysql->select( 'names', ['name'], { name => 'fuck' } )->hash;
is( $hash->{name}, undef, 'test delete names result ok' );
$mysql->insert_or_update( 'names', { name => 'tim' }, { name => 'time' } );
$hash = $mysql->select( 'names', ['name'], { name => 'tim' } )->hash;
is( $hash->{name}, 'tim', 'test insert or update names result ok' );

done_testing;

