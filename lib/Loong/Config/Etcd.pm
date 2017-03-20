package Loong::Config::Etcd;

use Loong::Base -base;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

use constant API_VERSION => 'v2';

has uri => '127.0.0.1:2379';
has ua  => sub { Mojo::UserAgent->new };
has api => sub { shift->_spec_api_link };

sub _spec_api_link {
    my ($self) = @_;
    return join( '/', 'http://' . $self->uri, API_VERSION, 'keys' );
}

sub get {
    my ( $self, $key ) = @_;
    return decode_json $self->ua->get( join( '/', $self->api, $key ) )->result->json('/node/value');
}

sub set {
    my ( $self, $key, $val ) = @_;
    return $self->ua->put(
        join( '/', $self->api, $key ) => form => {
            value => encode_json($val)
        }
    )->result->json;
}

sub update {
}

1;
__END__
