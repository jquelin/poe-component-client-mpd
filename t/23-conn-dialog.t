#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Connection;
use POE::Component::Client::MPD::Message;
use Readonly;
use Test::More;


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test dont_start_poe => 1';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
plan tests => 25;


# tests to be run
my @tests = (
    [ 'bad command', $RAW,         '_mpd_error', \&_check_bad_command      ],
    [ 'status',      $RAW,         '_mpd_data',  \&_check_data_raw         ],
    [ 'lsinfo',      $AS_ITEMS,    '_mpd_data',  \&_check_data_as_items    ],
    [ 'stats',       $STRIP_FIRST, '_mpd_data',  \&_check_data_strip_first ],
    [ 'stats',       $AS_KV,       '_mpd_data',  \&_check_data_as_kv       ],
);

Readonly my $ALIAS => 'tester';
my $id = POE::Session->create(
    inline_states => {
        # private events
        _start     => \&_onpriv_start,
        _next_test => \&_onpriv_next_test,
        # protected events
        _mpd_data    => \&_onprot_mpd_result,
        _mpd_error   => \&_onprot_mpd_result,
        _mpd_version => \&_onprot_mpd_version,
    }
);
my $conn = POE::Component::Client::MPD::Connection->spawn( {
    host => 'localhost',
    port => 6600,
    id   => $id,
} );
my $msg  = POE::Component::Client::MPD::Message->new({});
POE::Kernel->run;
exit;


#--
# private subs

sub _check_bad_command {
    like($_[0]->error, qr/unknown command "bad"/, 'unknown command');
}
sub _check_data_as_items {
    isa_ok( $_, 'POE::Component::Client::MPD::Item',
            '$AS_ITEMS cooks as items' ) for @{ $_[0]->data };
}
sub _check_data_as_kv {
    my %h = @{ $_[0]->data };
    unlike( $h{$_}, qr/\D/, '$AS_KV cooks as a hash' ) for keys %h;
    # stats return numerical data as second field.
}
sub _check_data_raw {
    isnt(scalar @{ $_[0]->data }, 0, 'commands return stuff' );
}
sub _check_data_strip_first {
    unlike( $_, qr/\D/, '$STRIP_FIRST return only 2nd field' ) for @{ $_[0]->data };
    # stats return numerical data as second field.
}


#--
# protected events

#
# event: _mpd_data ( $msg )
# event: _mpd_error( $msg )
#
# Called when mpd talks back, with $msg as a pococm-message param.
#
sub _onprot_mpd_result {
    is( $_[STATE], $tests[0][2], "got a $tests[0][2] event" );
    $tests[0][3]->( $_[ARG0] );         # check if everything went fine
    shift @tests;                       # remove test being played
    $_[KERNEL]->yield( '_next_test' );  # call next test
}


#
# event: _mpd_version( $version )
#
# Called when mpd gives its $version.
#
sub _onprot_mpd_version {
    $_[KERNEL]->yield( '_next_test' );
}


#--
# private events

#
# event: _start()
#
# Called when the poe session has started.
#
sub _onpriv_start {
    $_[KERNEL]->alias_set($ALIAS); # increment refcount
}


#
# event: _next_test()
#
# Called to schedule the next test.
#
sub _onpriv_next_test {
    my $k = $_[KERNEL];

    if ( scalar @tests == 0 ) { # no more tests.
        $k->alias_remove($ALIAS);
        $k->post( $conn, 'disconnect' );
        return;
    }

    # post next event.
    $msg->_commands( [ $tests[0][0] ] );
    $msg->_cooking (   $tests[0][1]   );
    $k->post( $conn, 'send', $msg );
}

