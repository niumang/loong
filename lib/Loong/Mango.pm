package Loong::Mango;

use Loong::Base 'Mango';
use Mojo::IOLoop;

sub save_crawl_info {
    my ( $self, $crawled, $db, $collection ) = @_;

    my $set        = '$set';
    my $collection = $self->db( $self->trim_db($db) )->collection($collection);
    print "collection is " . $collection . "\n";
    die "xxxxx";

    my $opts = {
        query  => { url_md5 => $crawled->{url_md5} },
        update => { $set    => $crawled }
    };

    #retutn $collection->insert($crawled,sub {} );
    return $collection->insert($crawled);

=pod
    return $collection->find_and_modify(
        $opts => sub {
            my ($collection, $err, $doc) = @_;
            # todo support failed insert db
            return defined $doc ? $doc : $collection->insert($crawled => sub { });
        }
    );
=cut

}

sub trim_db {
    my ( $self, $seed ) = @_;
    $seed =~ s/www.//g;
    $seed =~ s/.com//g;
    $seed =~ s/\./_/g;
    return $seed;
}

sub ensure_collection {
    my ( $self, $collection, $name ) = @_;
    $collection->create($name) unless $collection->name;
    return $collection;
}

sub get_counter_collection_by {
    my ( $self, $seed ) = @_;

    my $db = $seed;

    # 替换掉域名里面的点和 www com，防止生成不合法的 db
    $db =~ s/www.//g;
    $db =~ s/.com//g;
    $db =~ s/\./_/g;
    return $self->db($db)->collection('counter');
}
1;
