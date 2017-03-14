use Mojo::UserAgent;
use Mojo::UserAgent::CookieJar;
use Env qw(HOME);
use File::Spec;
use YAML qw(DumpFile Dump);

my $ua = Mojo::UserAgent->new;
$ua->max_redirects(3);
$ua->cookie_jar(Mojo::UserAgent::CookieJar->new);
$ua->get('https://www.baidu.com');

my $jar = $ua->cookie_jar;
my $path = File::Spec->catfile($HOME,'.cookie');
system("mkdir -p $path");
my $interval = shift||3600*24*7;
my $dump = {
    expire => time()+$interval,
    cookies => [ $jar, ],
};
my $file = File::Spec->catfile($path,'www.baidu.com');
DumpFile($file,$dump);



