package Loong::Scraper;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::DOM;
use Mojo::Util qw(monkey_patch dumper);
use Encode qw(find_encoding);
use Loong::Mojo::Log;

my $scraper = {};

sub import{
    my $class = shift;

    return unless my $flag= shift;

    if($flag eq '-route'){
        my $caller = caller;
        no strict 'refs';
        push @{"${caller}::ISA"}, __PACKAGE__;

        monkey_patch $caller, 'has', sub { Mojo::Base::attr($caller, @_) };

        for my $method (qw(get post put delete)){
            monkey_patch $caller =>  $method =>  sub {
                my ($url_pattern,$cb) = (shift,pop);
                my ($headers,%attr);
                $headers = shift if @_==1;
                %attr = @_ if @_==2;
                ($headers,%attr) = @_ if @_==3;

                my $key = join('|',$method,$url_pattern);
                $scraper->{$key}->{method} = $method;
                $scraper->{$key}->{cb} = $cb;
                $scraper->{$key}->{headers} = $headers if ref $headers;
                $scraper->{$key}->{form} = $attr{form} if ref $attr{form};
                return $scraper;
            };
        }
    }
}

has [qw(url alias cb headers form key pattern domain)];
has method => 'get';
has log    => sub { Loong::Mojo::Log->new };

# <meta charset="UTF-8">
my $charset_re = qr{charset\s*=\s*['"](.+?)["']}i;

sub new{
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    die "无效的域名" unless $self->domain;
    return $self;
}

sub _trim_url{
    my ($url)  = @_;

    my $ihost = Mojo::URL->new($url)->ihost;
    $ihost=~ s/www.//g;
    $ihost=~ s/.(?:com|me|mobi|net.cn|zh|pl)//g;
    return $ihost;
}

sub scrape {
    my ($self, $url, $res, $ctx) = @_;
    $self->match($url);

    Carp::croak "无效的 url 匹配: $url with pattern ".dumper($scraper) unless $self->key;

    if(!defined $res){
        use Mojo::UserAgent;
        $res = Mojo::UserAgent->new->get($url)->res;
    }

    my $type = $ctx->{type};
    my $dom;
    if (defined $type && $type eq 'javascript') {
        $dom = $res->body;
    }
    else {
        $dom = Mojo::DOM->new($self->decoded_body($res));
    }
    return $self->cb->($self, $dom, $ctx, @_);
}

sub resolve_href {
    my ($self, $base, $href) = @_;
    $href //= '';
    $href =~ s{\s}{}g;
    $href = ref $href ? $href : Mojo::URL->new($href);
    $base = ref $base ? $base : Mojo::URL->new($base);
    my $abs = $href->to_abs($base)->fragment(undef);
    while ($abs->path->parts->[0] && $abs->path->parts->[0] =~ /^\./) {
        shift @{$abs->path->parts};
    }
    $abs->path->trailing_slash($base->path->trailing_slash)
      if (!$href->path->to_string);
    return $abs;
}

sub _guess_encoding_css {
    return (shift =~ qr{^\s*\@charset ['"](.+?)['"];}is)[0];
}

sub decode_js {
    my ($self, $js) = @_;
    my $enc = _guess_encoding_javascript($js);
    $self->log->debug("指定 js 编码: $enc");
    return _encoder($enc)->decode($js);
}

sub _guess_encoding_javascript {
    my $js      = shift;
    my $charset = ($js =~ $charset_re)[0];
    return $charset;
}

sub _guess_encoding_html {
    my $head = (shift =~ qr{<head>(.+)</head>}is)[0] or return;
    my $charset;

    for my $e (Mojo::DOM->new($head)->find('meta')->each) {
        $charset = $1 if "$e"=~ m/$charset_re/ || "$e"=~ m/charset=(\S+?)"/;
        last if $charset;
    }
    return $charset;
}

sub decoded_body {
    my ($self, $res) = @_;
    my $enc = _guess_encoding($res);
    $self->log->debug("查找到 HTML 编码: $enc") if $enc;
    return _encoder($enc)->decode($res->body);
}

sub _encoder {
    my ($encoding) = @_;
    for ($encoding || 'utf-8', 'utf-8') {
        if (my $enc = find_encoding($_)) {
            return $enc;
        }
    }
}

sub _guess_encoding {
    my ($res) = @_;
    my $type = $res->headers->content_type;

    return unless ($type);

    my $charset = ($type =~ $charset_re)[0];

    return $charset                         if ($charset);
    return _guess_encoding_html($res->body) if $type =~ qr{text/(html|xml)};
    return _guess_encoding_css($res->body)  if $type =~ qr{text/css};
}

sub match {
    my ( $self,$url ) = @_;
    # todo: 从 cache 获取 callback
    for my $key(keys %$scraper){
        my ($method,$pattern) = $key=~ m/^(.+?)\|(.*)$/i;
        next unless $url=~ m/$pattern/i;
        next unless lc $self->method eq lc $method;

        $self->url($url);
        $self->cb($scraper->{$key}->{cb});
        $self->headers($scraper->{$key}->{headers});
        $self->key($key);
        $self->form($scraper->{$key}->{form});
    }
    return $self;
}
1;
