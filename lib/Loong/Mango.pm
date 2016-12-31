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

    my $doc = $collection->find_one({ url_md5 => $crawled->{url_md5}});
    if($doc){
        $collection->remove($doc->{_id});
    }
    return $collection->insert($crawled);
=pod
    return $collection->find_and_modify(
        $opts => sub {
            my ( $collection, $err, $doc ) = @_;
            # TODO support failed insert db
            print "mango saved $crawled->{url} ".Dump($crawled)."\n";
            return
              defined $doc ? $doc : $collection->insert( $crawled => sub { } );
        }
    );
=cut
}


1;
