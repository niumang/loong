use lib '../lib';
use Test::More;

require_ok('Loong::Mojo::UserAgent::Pool');

my $lup = Loong::Mojo::UserAgent::Pool->new;

like( $lup->get('web'),    qr/\S+/, '测试web类型useragent' );
like( $lup->get('mobile'), qr/\S+/, '测试mobile类型useragent' );
like( $lup->get(),         qr/\S+/, '测试默认类型useragent' );

eval { $lup->get('fuck') };
like( $@, qr/\S+/, '测试找不到类型useragent' );

done_testing;
