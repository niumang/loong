package Loong::Scraper;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::DOM;
use Encode qw(find_encoding);
use Loong::Mojo::Log;

has key    => 0;
has method => 'get';
has domain => '';
has log    => sub { Loong::Mojo::Log->new };

# <meta charset="UTF-8">
my $charset_re = qr{charset\s*=\s*['"](.+?)["']}i;

sub scrape {
    my ($self, $res, $ctx) = @_;

    Carp::croak "invalid url_pattern : " . $self->key unless $self->key;

    my $type = $ctx->{type};
    my $dom;
    if ($type eq 'javascript') {
        $dom = $res->body;
    }
    else {
        $dom = Mojo::DOM->new($self->decoded_body($res));
    }
    return $self->scraper->{$self->key}->{$self->method}->{cb}->($self, $dom, $ctx, @_);
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
        do { $charset = $1; last } if "$e" =~ m/$charset_re/;
    }
    return $charset;
}

sub decoded_body {
    my ($self, $res) = @_;
    my $enc = _guess_encoding($res);
    $self->log->debug("查找到 HTML 编码: $enc");
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

1;
