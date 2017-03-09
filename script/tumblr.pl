use lib '../lib';
use Loong::Lite;

my @video_list;
my @mp4s;
my $target_path = '/tmp/';

get '\w+.tumblr.com' => sub {
    my ( $self, $dom, $ctx ) = @_;
    for my $e ( $dom->find('div.tumblr_video_container')->each ) {
        push @video_list, $e->at('iframe')->{src};
    }
};

get 'video/.+?/\d+/\d+' => sub {
    my ( $self, $dom, $ctx ) = @_;
    if ( "$dom" =~ m{video_file/.+?/\d+/(tumblr_\w+)} ) {
        my $mp4 = 'https://vtt.tumblr.com/' . $1 . ".mp4";
        print "mp4 => $mp4\n";
        push @mp4s, $mp4;
    }
};

run('caobiya.tumblr.com');
run($_) for @video_list;
download( $_, $target_path ) for @mp4s;
__END__
