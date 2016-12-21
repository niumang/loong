package Loong::Scraper::Hhssee;

use Mojo::Base 'Loong::Scraper';
use Loong::Route;

get '/manhua/\d+.html' => sub {
    print "hello world";
};

1;


