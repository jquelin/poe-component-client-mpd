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

use POE qw[ Component::Client::MPD::Connection ];
use Readonly;
use Test::More;

my $sendmail_running = grep { /:25\s.*LISTEN/ } qx[ netstat -an ];
plan skip_all => 'need some sendmail server running' unless $sendmail_running;

plan tests => 1;

Readonly my $ALIAS => 'tester';

my $id = POE::Session->create(
    inline_states => {
        _start     => \&_onpriv_start,
        _mpd_error => \&_onpriv_mpd_error,
    }
);
my $conn = POE::Component::Client::MPD::Connection->spawn( {
    host => 'localhost',
    port => 25,
    id   => $id,
} );
POE::Kernel->run;
exit;


sub _onpriv_start {
    $_[KERNEL]->alias_set($ALIAS); # increment refcount
}

sub _onpriv_mpd_error  {
    my $k = $_[KERNEL];
    like( $_[ARG0]->error, qr/^Not a mpd server - welcome string was:/, 'wrong server');
    $k->alias_remove($ALIAS); # increment refcount
    $k->post( $conn, 'disconnect' );
}

