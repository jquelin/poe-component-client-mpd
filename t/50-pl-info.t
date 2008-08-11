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

my @songs   = qw{
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
};
my $nbtests = 14;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    [ 'pl.clear',                [], 0, \&check_success       ],
    [ 'pl.add',             \@songs, 0, \&check_success       ],

    # pl.as_items
    [ 'pl.as_items',             [], 0, \&check_as_items      ],

    # pl.items_changed_since
    [ 'pl.items_changed_since', [0], 0, \&check_items_changed ],

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

sub check_as_items {
    my ($msg, $items) = @_;
    check_success($msg);
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'pl.as_items() return') for @$items;
    is($items->[0]->title, 'ok-title', 'first song reported first');
}

sub check_items_changed {
    my ($msg, $items) = @_;
    check_success($msg);
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'items_changed_since() return') for @$items;
    is($items->[0]->title, 'ok-title', 'first song reported first');
}
