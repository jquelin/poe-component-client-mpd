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

use Test::More;

my $nbtests = 12;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # all_albums
    [ 'coll.all_albums',  [], 0, \&check_all_albums  ],

    # all_artists
    [ 'coll.all_artists', [], 0, \&check_all_artists ],

    # all_titles
    [ 'coll.all_titles',  [], 0, \&check_all_titles  ],

    # all_files
    [ 'coll.all_files',   [], 0, \&check_all_files   ],

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

sub check_all_albums {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 1, 'all_albums() return the albums');
    is($items->[0], 'our album', 'all_albums() return strings');
}

sub check_all_artists {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 1, 'all_artists() return the artists');
    is($items->[0], 'dir1-artist', 'all_artists() return strings');
}

sub check_all_titles {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 3, 'all_titles() return the titles');
    like( $items->[0], qr/-title$/, 'all_titles() return strings');
}


sub check_all_files {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 4, 'all_files() return the pathes');
    like($items->[0], qr/\.ogg$/, 'all_files() return strings');
}
