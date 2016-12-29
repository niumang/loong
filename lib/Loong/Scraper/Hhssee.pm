package Loong::Scraper::Hhssee;

use Mojo::Base 'Loong::Scraper';
use Loong::Route;
use Mojo::Util qw(dumper);

# http://www.hhssee.com
get 'hhssee.com$' => sub {
    my ($self,$dom,$ctx) = @_;
    my $url = $ctx->{tx}->req->url;
    my $ret = { nexts => [] };

    for my $e($dom->at('div.cHNav')->find('a')->each){
        #/comic/class_1.html
        if($e->{href}=~ m/class_\d+.html/){
            push @{ $ret->{nexts} },{ url => $ctx->{base}.$e->{href} };
        }
    }
    $ret->{url} = $url;
    return $ret;
};

# http://www.hhssee.com/comic/class_4.html
get 'comic/class_\d+.html' =>sub {
    my ($self,$dom,$ctx) = @_;

    my $url = $ctx->{tx}->req->{url};
    my $ret = { nexts => [] };
    my @nexts;
    for my $e($dom->at('div.cComicList')->find('a')->each){
        my $item = {
            url => $ctx->{base}.$e->{href},
            topic => $e->at('img')->{src},
            name => $e->all_text,
        };
        push @nexts,$item;
    }
    $ret->{url} = $url;
    $ret->{nexts} = \@nexts;
    return $ret;
};

get '/manhua\d+.html' => sub {
    my ($self,$dom,$ctx) = @_;

    my $url = $ctx->{tx}->req->{url};
    my $ret = { nexts => [] };
    my @nexts;

    my $about_kit = $dom->at('#about_kit');
    my $list_index = {
        title => 0,
        author => 1,
        status => 2,
        episodes => 3,
        last_update => 4,
        store=> 5,
        rating => 6,
        desc => 7,
    };
    my @ul = $about_kit->find('li')->each;
    for my $key(keys %$list_index){
        $ret->{$key} = $ul[$list_index->{$key}]->all_text;
        $ret->{$key} =~ s/(作者:|简介:|集数:|更新:|评价:|状态:)//g;
        $ret->{$key} =~ s/^\s+//g;
        $ret->{$key} =~ s/\s+$//g;
    }
    for my $e($dom->at('ul.cVolUl')->find('a')->each ){
        my $title = $e->text;
        my $url = $ctx->{base}.$e->{href};
        push @nexts,{ title => $title, url => $url };
    }
    my ($y,$m,$d) = $ret->{last_update}=~ m{(\d+)/(\d+)/(\d+)};
    my ($rating,$comment_times) = $ret->{rating}=~ m/([\d\.]+).+?\s*(\d+)/s;
    ($ret->{store})= $ret->{store}=~ m/(\d+)/;
    $ret->{last_update} = sprintf('%.4d-%.2d-%.2d',$y,$m,$d);
    $ret->{rating} = $rating;
    $ret->{comment_times} = $comment_times;
    $ret->{url} = $url;
    $ret->{nexts} = \@nexts;
    return $ret;
};

# http://www.hhssee.com/page101331/1.html?s=4
get '/page\d+/1.html.s=\d+' => sub {
    my ($self,$dom,$ctx) = @_;

    my $url = $ctx->{tx}->req->{url};
    my $ret = { nexts => [] };
    my @nexts;

    my ($title) = $dom->at('title')->all_text;
    $title =~ s/ - 汗汗漫画//g;
    $title =~ s/\r|\n|\t|\s+//g;
    my $total = $dom->at('#hdPageCount')->{value};
    my ($prefix,$s);
    if($url=~ m{(.+?)/\d+.html.s=(\d+)}){
        $prefix = $1;
        $s = $2;
    }
    # 添加 long= 用于区分下一集抓取图片的链接
    my @pages = map { $prefix."/$_.html?s=$s&loong=&d=0" } (1..$total);
    for my $p(@pages){
        push @nexts,{ url => $p, title => $title };
    }
    $ret->{url} = $url;
    $ret->{title} = $title;
    $ret->{nexts} = \@nexts;

    return $ret;
};

get '/page\d+/\d+.html.s=\d+.long=' => sub {
    my ($self,$dom,$ctx) = @_;

    my $url = $ctx->{tx}->req->{url};
    my $ret = { nexts => [] };
    my @nexts;

    my $img_info = parse_photo("$url",$dom);

    push @{ $ret->{nexts} },$img_info;
    $ret->{url} = $url;

    return $ret;
};

sub decode_comic_image {
    my $s  = shift;
    my $sw = "hhssee.com|9eden.com";
    my $su = "hhssee.com";
    my $b  = 0;

    for ( my $i = 0 ; $i < scalar( split( '|', $sw ) ) ; $i++ ) {
        my $e = [ split( '|', $sw ) ]->[$i];
        if ( $su =~ m/$e/i ) {
            $b = 1;
            last;
        }
    }

    return unless $b;

    my $x = substr( $s, length($s) - 1 );
    my $xi = index( "abcdefghijklmnopqrstuvwxyz", $x ) + 1;

    my $sk = substr(
        $s,
        length($s) - $xi - 12,
        length($s) - $xi - 1 - ( length($s) - $xi - 12 )
    );
    $s = substr( $s, 0, length($s) - $xi - 12 );
    my $k = substr( $sk, 0, length($sk) - 1 );
    my $f = substr( $sk, length($sk) - 1 );

    for ( my $i = 0 ; $i < length($k) ; $i++ ) {
        my $e = substr( $k, $i, $i + 1 - $i );
        my $r = $i;
        $s =~ s/$e/$r/g;
    }
    my @ss = split( $f, $s );
    $s = '';
    for ( my $i = 0 ; $i < @ss ; $i++ ) {
        $s .= chr( $ss[$i] );
    }
    return $s;
}

sub parse_photo {
    my $url      = shift;
    my $dom = shift;
    my $img_info = {};

    my @hd_domains = split( /\|/, $dom->at('#hdDomain')->{value} );
    my $name = 'd';
    my $cu_domain_no;

  # http://163.94201314.net/dm01//ok-comic12/Y/YanMu/vol_06/99770_0030_19702.JPG
  # "(^|\?|&)=([^&]*)(\s|&|$)"
    if ( $url =~ m/(^|\?|&)=([^&]*)(\s|&|$)/ ) {
        $cu_domain_no = $2;
    }
    $cu_domain_no ||= 0;

    #if(arrDS.length==1) return arrDS[0];
    #return arrDS[s];
    my $img_domain =
      @hd_domains == 1 ? $hd_domains[0] : $hd_domains[$cu_domain_no];
    $img_domain =~ s{/$}{};
    my $img_name;
    my $img_id;

    for my $e ( $dom->find('img')->each ) {
        if ( $e->{id} =~ m/img(\d+)/ ) {
            $img_name = $e->{name};
            $img_id   = $1;
            last;
        }
    }

    $img_info->{name} = $img_name;
    $img_info->{id}   = $img_id;
    $img_info->{url}  = join( '/', $img_domain, decode_comic_image($img_name) );
    $img_info->{domain} = $img_domain;

    return $img_info;
}

1;


