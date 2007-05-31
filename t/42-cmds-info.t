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

use POE qw[ Component::Client::MPD::Message ];
use Readonly;
use Test::More;


our $nbtests = 16;
my @songs = qw[ title.ogg dir1/title-artist-album.ogg dir1/title-artist.ogg ];
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # stats
    [ 'updatedb', [],      $DISCARD, undef                ],
    [ 'pl.add',   \@songs, $DISCARD, undef                ],
    [ 'stats',    [],      $SEND,    \&check_stats        ],

    # status
    [ 'play',     [],      $DISCARD, undef                ],
    [ 'pause',    [],      $DISCARD, undef                ],
    [ 'status',   [],      $SEND,    \&check_status       ],

    # current
    [ 'current',  [],      $SEND,    \&check_current      ],

    # song
    [ 'song',     [1],     $SEND,    \&check_song         ],
    [ 'song',     [],      $SEND,    \&check_song_current ],

    # songid (use the same checkers as song)
    [ 'songid',   [1],     $SEND,    \&check_song         ],
    [ 'songid',   [],      $SEND,    \&check_song_current ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;


sub check_stats {
    my $stats = $_[0]->data;
    isa_ok( $stats, 'Audio::MPD::Common::Stats',
            'stats() returns an amc::stats object' );
    is( $stats->artists,      1, 'one artist in the database' );
    is( $stats->albums,       1, 'one album in the database' );
    is( $stats->songs,        4, '4 songs in the database' );
    is( $stats->playtime,     0, 'already played 0 seconds' );
    is( $stats->db_playtime,  8, '8 seconds worth of music in the db' );
    isnt( $stats->uptime, undef, 'uptime is defined' );
    isnt( $stats->db_update,  0, 'database has been updated' );
}

sub check_status {
    my $status = $_[0]->data;
    isa_ok( $status, 'Audio::MPD::Common::Status',
            'status return an amc::status object' );
}

sub check_current {
    my $song = $_[0]->data;
    isa_ok( $song, 'Audio::MPD::Common::Item::Song',
            'current return an AMC::Item::Song object' );
}

sub check_song {
    my $song = $_[0]->data;
    isa_ok( $song, 'Audio::MPD::Common::Item::Song',
            'song(id) returns an AMC::Item::Song object' );
    is( $song->file, 'dir1/title-artist-album.ogg', 'song(id) returns the wanted song' );
}

sub check_song_current {
    my $song = $_[0]->data;
    is( $song->file, 'title.ogg', 'song(id) defaults to current song' );
}
