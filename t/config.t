use lib "../lib";

use Test::More;
use Loong::Config;

my $config = Loong::Config->new;
like( $config->root,            qr/loong/, '测试根目录: ' . $config->root );
like( $config->mango_uri,       qr/27017/, '测试 mango 连接地址: ' . $config->mango_uri );
like( $config->mysql_uri,       qr/mysql/, '测试 mysql uri: ' . $config->mysql_uri );
like( $config->app_log,         qr/.log/,  '测试日志路径: ' . $config->app_log );
like( $config->app_process_num, qr/\d+/,   '测试并发数目: ' . $config->app_process_num );
like( $config->app_debug,       qr/\d+/,   '测试 debug 开关: ' . $config->app_debug );
done_testing();
