package Loong::Mojo::UserAgent::CookieJar;

use Env qw(HOME);
use Loong::Base 'Mojo::UserAgent::CookieJar';
use File::Spec;
use Encode qw(encode_utf8);
use Mojo::File 'path';
use constant DEBUG => $ENV{LOONG_DEBUG};

has cookie_path => sub { File::Spec->catdir( $HOME, '.cookie' ) };
has 'cookie_script';

sub new {
    my $self = shift->SUPER::new(@_);
    path( $self->cookie_path )->make_path unless -d $self->cookie_path;
    return $self;
}

sub cached_cookie {
    my ( $self, $tx ) = @_;

    my $now         = time;
    my $ihost       = $tx->req->url->ihost;
    my $cookie_file = File::Spec->catfile( $self->cookie_path, $ihost );
    my $cookie_jar;

    warn "dumper cookie_file = $cookie_file\n" if DEBUG;

    my $load;
    eval { $load = LoadFile($cookie_file) };

    # cookie文件没有生成或者 cookie文件为空，执行cookie生成一次
    if ( !-e $cookie_file or !$load ) {
        $self->_reload_cookie($cookie_file);
    }

    $cookie_jar = $self->rand_cookie( $load->{cookies} );
    warn encode_utf8( "获取rand cookie从文件: " . Dump($cookie_jar) ) if DEBUG;
    Carp::croak encode_utf8 "cookie生效时间没有指定" unless my $exp = $load->{expire};
    $cookie_jar = $self->_reload_cookie($cookie_file) if time() >= $exp;

    return $self->cookie_jar($cookie_jar);
}

sub _reload_cookie {
    my ( $self, $cookie_file ) = @_;

    my $cmd;

    # 7天过期
    $cmd = join( ' ', 'perl', $self->cookie_script, 3600 * 24 * 7 );
    chmod 0755, $self->cookie_script;
    warn "$cmd\n" if DEBUG;
    system($cmd);
    my $load;
    eval { $load = LoadFile($cookie_file) };

    Carp::croak encode_utf8 "生成cookie文件失败,或者cookie脚本生产了错误的cookie"
      unless $load;

    return $self->rand_cookie( $load->{cookies} );
}

sub rand_cookie {
    my ( $self, $data ) = @_;
    return $data->[ int( rand @$data ) ];
}
1;

__END__
