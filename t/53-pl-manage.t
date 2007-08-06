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
use FindBin qw[ $Bin ];
use Readonly;
use Test::More;


our $nbtests = 4;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # load
    [ $PLAYLIST, 'load',     ['test'], $DISCARD, undef        ],
    [ $PLAYLIST, 'as_items', [],       $SEND,    \&check_load ],

    # save
    [ $PLAYLIST, 'save',     ['test-jq'], $DISCARD, undef        ],
    [ $MPD,      'status',   [],          $SEND,    \&check_save ],

    # rm
    [ $PLAYLIST, 'rm',       ['test-jq'], $DISCARD, undef      ],
    [ $MPD,      'status',   [],          $SEND,    \&check_rm ],
);

# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_load {
    my @items = @{ $_[0]->data };
    is( scalar @items, 1, 'pl.load() adds songs' );
    is( $items[0]->title, 'ok-title', 'pl.load() adds the correct songs' );
}

sub check_save {
    ok( -f "$Bin/mpd-test/playlists/test-jq.m3u", 'pl.save() creates a playlist' );
}

sub check_rm {
    ok( ! -f "$Bin/mpd-test/playlists/test-jq.m3u", 'rm() removes a playlist' );
}
