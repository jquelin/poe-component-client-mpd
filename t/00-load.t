#!perl

use strict;
use warnings;

use Test::More tests => 6;

BEGIN { use_ok( 'POE::Component::Client::MPD' ); }
my $version = $POE::Component::Client::MPD::VERSION;
diag( "Testing POE::Component::Client::MPD $version, Perl $], $^X" );

use_ok( 'POE::Component::Client::MPD::Message' );
use_ok( 'POE::Component::Client::MPD::Collection' );
use_ok( 'POE::Component::Client::MPD::Commands' );
use_ok( 'POE::Component::Client::MPD::Playlist' );
use_ok( 'POE::Component::Client::MPD::Connection' );
exit;
