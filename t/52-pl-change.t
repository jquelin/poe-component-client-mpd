#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;

use Test::More;

my $plvers;
my @songs   = qw{
    title.ogg
    dir1/title-artist-album.ogg
    dir1/title-artist.ogg
    dir2/album.ogg
};
my $nbtests = 20;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # pl.swapid
    # test should come first to know the song id
    [ 'pl.clear',         [], 0, \&check_success ],
    [ 'pl.add',      \@songs, 0, \&check_success ],
    [ 'pl.swapid',     [0,2], 0, \&check_success ],
    [ 'pl.as_items',      [], 0, \&check_2ndpos  ],
    [ 'pl.swapid',     [0,2], 0, \&check_success ],

    # pl.moveid
    # test should come second to know the song id
    [ 'pl.moveid',     [0,2], 0, \&check_success ],
    [ 'pl.as_items',      [], 0, \&check_2ndpos  ],
    [ 'pl.moveid',     [0,0], 0, \&check_success ],

    # pl.swap
    [ 'pl.swap',       [0,2], 0, \&check_success ],
    [ 'pl.as_items',      [], 0, \&check_2ndpos  ],
    [ 'pl.swap',       [0,2], 0, \&check_success ],

    # pl.move
    [ 'pl.move',       [0,2], 0, \&check_success ],
    [ 'pl.as_items',      [], 0, \&check_2ndpos  ],

    # pl.shuffle
    [ 'status',           [], 0, sub { $plvers=$_[1]->playlist; } ],
    [ 'pl.shuffle',       [], 0, \&check_success                  ],
    [ 'status',           [], 0, \&check_shuffle                  ],
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

sub check_shuffle {
    my ($msg, $status) = @_;
    check_success($msg);
    is($status->playlist, $plvers+1, 'shuffle() changes playlist version');
}

sub check_2ndpos {
    my ($msg, $items) = @_;
    check_success($msg);
    is($items->[2]->title, 'ok-title', 'swap[id()] / swap[id()] changes songs');
}
