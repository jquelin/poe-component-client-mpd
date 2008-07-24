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
use POE::Component::Client::MPD;
use POE::Component::Client::MPD::Message;
use Readonly;
use Test::More;

my $nbtests = 11;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # updatedb
    [ 'updatedb',    [],       1, \&check_success     ],
    [ 'stats',       [],       0, \&check_update      ],
    [ 'updatedb',    ['dir1'], 0, \&check_success     ],
    [ 'stats',       [],       0, \&check_update      ],

    # version
    # needs to be *after* updatedb, so version messages can be treated
    # by socket.
    [ 'version',     [],       0, \&check_version     ],

    # urlhandlers
    [ 'urlhandlers', [],       0, \&check_urlhandlers ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test nbtests=>$nbtests, tests=>\@tests';
diag($@), plan skip_all=>$@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

#--

sub check_success {
    my ($msg) = @_;
    is($msg->status, 1, "command '" . $msg->request . "' returned an ok status");
}

sub check_update  {
    my ($msg, $stats) = @_;
    check_success($msg);
    isnt( $stats->db_update,  0, 'database has been updated' );
}

sub check_urlhandlers {
    my ($msg, $handlers) = @_;
    check_success($msg);
    is(scalar @$handlers,         1, 'only one url handler supported');
    is($handlers->[0],    'http://', 'only http is supported by now');
}

sub check_version {
    my ($msg, $vers) = @_;
    SKIP: {
        my $output = qx[mpd --version 2>/dev/null];
        skip 'need mpd installed', 2 unless $output =~ /^mpd .* ([\d.]+)\n/;
        check_success($msg);
        is($vers, $1, 'mpd version grabbed during connection is correct');
    }
}

