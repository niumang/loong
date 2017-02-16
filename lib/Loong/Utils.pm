package Loong::Utils;
use Mojo::Base -strict;

use Carp qw(carp croak);
use Data::Dumper ();
use Digest::MD5 qw(md5 md5_hex);
use Digest::SHA qw(hmac_sha1_hex sha1 sha1_hex);
use Encode 'find_encoding';
use Exporter 'import';
use Getopt::Long 'GetOptionsFromArray';
use Clone 'clone';
use List::Util 'min';
use MIME::Base64 qw(decode_base64 encode_base64);
use Time::HiRes ();

our @EXPORT_OK = (qw(merge_hash trim_domain trim));

# todo:  merge hash 同key不同值
sub merge_hash {
    my ( $hash_a, $hash_b ) = @_;

    if ( ref $hash_a ne 'HASH' || ref $hash_b ne 'HASH' ) {
        die "merge_hash 2个元素必须都是hash的引用";
    }
    my $final_hash = clone $hash_a;
    for my $b_key ( keys %$hash_b ) {
        $final_hash->{$b_key} = $hash_b->{$b_key} if !exists $hash_a->{$b_key};
    }
    return $final_hash;
}

sub trim_domain {
    my ($s) = @_;
    $s =~ s/www.//g;
    $s =~ s/\.(?:com|me|pl|net|zh|org|cn|info|tw)$//g;
    return $s;
}

sub trim {
    my ($s) = @_;
    $s =~ s/\s+$//g;
    $s =~ s/^\s+$//g;
    return $s;
}

1;
