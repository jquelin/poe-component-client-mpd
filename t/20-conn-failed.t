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
use Test::More;
plan tests => 1;

my $id = POE::Session->create(
    inline_states => {
        _start     => \&_onpriv_start,
        _mpd_error => \&_onpriv_mpd_error,
    }
);
POE::Component::Client::MPD::Connection->spawn( {
    host => 'localhost',
    port => 16600,
    id   => $id,
} );
POE::Kernel->run;
exit;


sub _onpriv_start {
    $_[KERNEL]->alias_set('tester'); # increment refcount
}

sub _onpriv_mpd_error  {
    like( $_[ARG0]->error, qr/^connect: \(\d+\) /, 'connect error trapped' );
}

