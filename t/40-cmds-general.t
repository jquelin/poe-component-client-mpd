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
use POE::Component::Client::MPD qw[ :all ];
use POE::Component::Client::MPD::Message;
use Readonly;
use Test::More;

our $nbtests = 5;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # updatedb
    [ $MPD, 'updatedb',    [],       $SLEEP1,  undef               ],
    [ $MPD, 'stats',       [],       $SEND,    \&check_update      ],
    [ $MPD, 'updatedb',    ['dir1'], $DISCARD, undef               ],
    [ $MPD, 'stats',       [],       $SEND,    \&check_update      ],

    # version
    # needs to be *after* updatedb, so version messages can be treated.
    [ $MPD, 'version',     [],       $SEND,    \&check_version     ],

    # urlhandlers
    [ $MPD, 'urlhandlers', [],       $SEND,    \&check_urlhandlers ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
diag($@), plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_version {
    SKIP: {
        my $output = qx[mpd --version 2>/dev/null];
        skip 'need mpd installed', 1 unless $output =~ /^mpd .* ([\d.]+)\n/;
        is( $_[0]->data, $1, 'mpd version grabbed during connection' );
    }
}
sub check_update  {
    my $stats = $_[0]->data;
    isnt( $stats->db_update,  0, 'database has been updated' );
}

sub check_urlhandlers {
    my @handlers = @{ $_[0]->data };
    is( scalar @handlers,     1, 'only one url handler supported' );
    is( $handlers[0], 'http://', 'only http is supported by now' );
}
