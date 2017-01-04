package Loong::Mango;

use Loong::Base 'Mango';

sub save_crawl_info {
    my ($self, $crawled, $seed) = @_;

    my $set        = '$set';
    my $collection = $self->get_counter_collection_by($seed);
    my $opts       = {
        query  => {url_md5 => $crawled->{url_md5}},
        update => {$set    => $crawled}
    };
    return $collection->find_and_modify(
        $opts => sub {
            my ($collection, $err, $doc) = @_;

            # todo support failed insert db
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
