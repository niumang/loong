use lib '../lib';
use Test::More;
use Loong::Mojo::UserAgent::CookieJar;
use Mojo::IOLoop;

require_ok('Loong::Mojo::UserAgent');
require_ok('Loong::Mojo::UserAgent::CookieJar');

my $ua = Loong::Mojo::UserAgent->new();
$ua->cookie_jar( Loong::Mojo::UserAgent::CookieJar->new( cookie_script => './gen_cookie.pl' ) );
$ua->get('https://www.baidu.com');
is( $ua->cookie_jar->all > 0, 1, '验证cookie选项存在' );
like( $_->name, qr/\S+/, '测试cookie 属性' . $_->name ) for @{ $ua->cookie_jar->all };

done_testing;
