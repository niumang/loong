package Loong::Mango;

use Loong::Base 'Mango';
use YAML qw(Dump);

sub new {
    my $self = shift->SUPER::new(@_);
    return $self;
}

sub mango { return Mango->new('mongodb://localhost:27017') }

sub save_crawl_info {
    my ( $self, $crawled, $ctx ) = @_;

    my $set        = '$set';
    my $collection = $ctx->{collection};
    my $opts       = {
        query  => { url_md5 => $crawled->{url_md5} },
        update => { $set    => $crawled }
    };

    return $collection->find_and_modify(
        $opts => sub {
            my ( $collection, $err, $doc ) = @_;
            # TODO support failed insert db
            return
              defined $doc ? $doc : $collection->insert( $crawled => sub {} );
        }
    );
}

sub get_counter_collection_by{
    my ($self,$seed) = @_;

    my $db = $seed;
    # 替换掉域名里面的点和 www com，防止生成不合法的 db
    $db=~ s/www.//g;
    $db=~ s/.com//g;
    $db=~ s/\./_/g;
    return $self->mango->db($db)->collection('counter')
}


1;
