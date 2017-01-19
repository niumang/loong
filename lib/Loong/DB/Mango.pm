package Loong::DB::Mango;

use Loong::Base 'Mango';
use Data::Dumper;

sub trim_db {
    my ($self, $db) = @_;
    $db =~ s/www.//g;
    $db =~ s/.com//g;
    $db =~ s/\./_/g;
    return $db;
}

sub save_crawl_info {
    my ($self, $crawled, $seed, $name) = @_;

    my $set        = '$set';
    my $db         = $self->trim_db($seed);
    my $collection = $self->db('hupu')->collection($name);
    my $opts       = {
        query  => {url  => $crawled->{url}},
        update => {$set => $crawled},
    };
    return $collection->find_and_modify(
        $opts => sub {
            my ($collection, $err, $doc) = @_;
            return defined $doc ? $doc : $collection->insert($crawled => sub { });
        }
    );
}

sub get_counter_collection_by {
    my ($self, $seed) = @_;

    my $db = $seed;

    # 替换掉域名里面的点和 www com，防止生成不合法的 db
    $db =~ s/www.//g;
    $db =~ s/.com//g;
    $db =~ s/\./_/g;
    return $self->db($db)->collection('counter');
}


1;
