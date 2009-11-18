#!perl

use 5.010;
use strict;
use warnings;

use Test::More;

my $nbtests = 10;
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
    TODO: {
        local $TODO = 'test depending on mpd compilation flags';
        is(scalar @$handlers, 0, 'no url handler supported by default');
    }
}

sub check_version {
    my ($msg, $vers) = @_;
    SKIP: {
        my $output = qx{echo | nc -w1 localhost 6600 2>/dev/null};
        skip 'need netcat installed', 2 unless $output =~ /^OK .* ([\d.]+)\n/;
        check_success($msg);
        is($vers, $1, 'mpd version grabbed during connection is correct');
    }
}

