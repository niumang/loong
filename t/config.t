    use lib "../lib";

    use Test::More;
    use Loong::Config; use Loong::Base -strict; use Encode qw(encode_utf8);

    my $config = Loong::Config->new;
like($config->root, qr/loong/, encode_utf8 '测试根目录: '.$config->root); like($config->mango_uri, qr/27017/, encode_utf8 '测试 mango 连接地址: '.$config->mango_uri); like($config->mysql_uri, qr/mysql/, encode_utf8 '测试 mysql uri: '. $config->mysql_uri); like($config->app_log, qr/loong.log/, encode_utf8 '测试日志路径: '. $config->app_log); like($config->app_process_num, qr/\d+/, encode_utf8 '测试并发数目: '. $config->app_process_num); like($config->app_debug, qr/\d+/, encode_utf8 '测试 debug 开关: '.$config->app_debug); my $cb = sub {my $a; my $b ; my $c }; done_testing();
