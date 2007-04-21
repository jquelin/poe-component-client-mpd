#!/usr/bin/env perl
#

use warnings;
use strict;

use lib 'lib';
use POE qw[ Component::Client::MPD ];

POE::Component::Client::MPD->spawn( {alias => 'mpd'} );
POE::Session->create(
    inline_states => {
        _start     => \&start,
        _stop      => sub { print "bye-bye\n"; },
        mpd_result => \&result,
    }
);
POE::Kernel->run;
exit;



sub start {
    my $k = $_[KERNEL];
    $k->alias_set('client'); # increment refcount
    $k->post( 'mpd', 'coll:all_files' );
}

sub result {
    print "yeah!\n";
}

