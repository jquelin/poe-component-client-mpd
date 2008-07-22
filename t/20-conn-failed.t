#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use 5.010;

use strict;
use warnings;

use POE qw[ Component::Client::MPD::Connection ];
use Readonly;
use Test::More;

plan tests => 2;
Readonly my $ALIAS => 'tester';


my $id = POE::Session->create(
    inline_states => {
        _start                      => \&_onpriv_start,
        mpd_connect_error_retriable => \&_onprot_mpd_connect_error_retriable,
    }
);
my $conn = POE::Component::Client::MPD::Connection->spawn( {
    host  => 'localhost',
    port  => 16600,
    id    => $id,
    #retry => 0.5,
} );
POE::Kernel->run;
exit;

#--

sub _onpriv_start {
    my ($k, $h) = @_[KERNEL, HEAP];
    $k->alias_set($ALIAS); # increment refcount
    $h->{count} = 0;
}

sub _onprot_mpd_connect_error_retriable {
    my ($k, $h, $errstr) = @_[KERNEL, HEAP, ARG0];
    given ($h->{count}++) {
        when (0) {
            like( $errstr, qr/^connect: \(\d+\) /, 'connect error trapped' );
        }
        when (1) {
            like( $errstr, qr/^connect: \(\d+\) /, 'connection retried' );
            $k->post($conn, 'disconnect');
            $k->alias_remove($ALIAS); # decrement refcount
        }
    }
}


