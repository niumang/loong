package Loong::Config;

use Loong::Base -base;
use File::Basename qw(basename dirname);
use File::Spec;
use Mojo::Util qw(monkey_patch);
use Mojo::File;
use File::Path qw(make_path remove_tree);
use Carp;

sub import {
    $ENV{LONG_EXE} = (caller)[1];

    my $caller   = caller;
    my $base     = basename $ENV{LONG_EXE};
    my $abs_path = File::Spec->rel2abs($base);
    my $root;
    $root = $1 if $abs_path =~ m{(.+loong)/};

    Carp::croak "请在项目目录下运行程序，否则依赖模块不能工作啊你妹!"
      unless $root;
    $ENV{LONG_HOME} //= $root;

    no strict 'refs';
    my $pkg = __PACKAGE__;
    monkey_patch $pkg => 'root' => sub { $root };
    monkey_patch $pkg => 'perllib' => sub { File::Spec->catdir( $root, 'lib' ) };
}

has path => sub { File::Spec->catdir( $ENV{LONG_HOME}, 'conf' ) };
has 'global';
has 'site';

sub new {
    my $self = shift->SUPER::new(@_);
    $self->parse( $self->path );
    return $self;
}

sub parse {
    my ( $self, $path ) = @_;

    my $global_ini = File::Spec->catdir( $self->path, 'loong.ini' );
    Carp::croak "$global_ini 配置文件目录不对\n" if not -e $global_ini;

    my $config = {};
    my $global = $self->read($global_ini);

    my @files = Mojo::File->new( $self->path )->list_tree->each;
    my ( $crawl, $load );

    while ( my $file = shift @files ) {
        next if $file =~ m/loong.ini$/;
        if ( $file =~ m{site/(.+?)/(crawl|load).ini} ) {
            $config->{site}->{$1}->{$2} = $self->read($file);
        }
    }
    $self->global($global);
    $self->site( $config->{site} );

    {
        no strict 'refs';
        my $pkg = __PACKAGE__;
        for my $method ( $self->_basic_attr ) {
            my ( $section, $key ) = $method =~ m/^(.+?)_(.+)/;
            my $result = $global->{$section}->{$key} || 'undef';
            monkey_patch $pkg => $method => sub { $result };
        }
    }
}

sub _basic_attr {
    qw(mango_uri mysql_uri redis_uri app_debug app_log app_process_num app_data app_log_level );
}

sub read {
    my ( $self, $file ) = @_;

    open( my $fh, "<", $file ) || die "can't open file => $file: $@\n";
    my $section;
    my $parsed = {};
    while ( my $line = <$fh> ) {
        chomp $line;
        $line =~ s/\s+$//g;
        if ( $line =~ m/^\[(.+?)\]/ ) {
            $section = $1;
        }
        if ( $line =~ m/^(.+?)\s*=\s*(.*)/ ) {
            my ( $k, $v ) = ( $1, $2 );
            $parsed->{$section}->{$k} = $v;
        }
    }
    close($fh);

    return $parsed;
}

1;

