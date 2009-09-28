#!perl

use strict;
use warnings;

use FindBin qw{ $Bin };
use Test::More;

my $nbtests = 11;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # load
    [ 'pl.clear',             [], 0, \&check_success ],
    [ 'pl.load',        ['test'], 0, \&check_success ],
    [ 'pl.as_items',          [], 0, \&check_load    ],

    # save
    [ 'pl.save',     ['test-jq'], 0, \&check_success ],
    [ 'status',               [], 0, \&check_save    ],

    # rm
    [ 'pl.rm',       ['test-jq'], 0, \&check_success ],
    [ 'status',               [], 0, \&check_rm      ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test nbtests=>$nbtests, tests=>\@tests';
diag($@), plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

#--

sub check_success {
    my ($msg) = @_;
    is($msg->status, 1, "command '" . $msg->request . "' returned an ok status");
}

sub check_load {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 1, 'pl.load() adds songs');
    is($items->[0]->title, 'ok-title', 'pl.load() adds the correct songs');
}

sub check_save {
    my ($msg, $status) = @_;
    check_success($msg);
    ok(-f "$Bin/mpd-test/playlists/test-jq.m3u", 'pl.save() creates a playlist');
}

sub check_rm {
    my ($msg, $status) = @_;
    check_success($msg);
    ok(! -f "$Bin/mpd-test/playlists/test-jq.m3u", 'rm() removes a playlist');
}
