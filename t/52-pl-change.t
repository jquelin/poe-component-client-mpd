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


my $plvers;
our $nbtests = 5;
my @songs = qw[
    title.ogg
    dir1/title-artist-album.ogg
    dir1/title-artist.ogg
    dir2/album.ogg
];
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # pl.swapid
    # test should come first to know the song id
    [ $PLAYLIST, 'clear',    [],       $DISCARD, undef          ],
    [ $PLAYLIST, 'add',      \@songs,  $DISCARD, undef          ],
    [ $PLAYLIST, 'swapid',   [0,2],    $DISCARD, undef          ],
    [ $PLAYLIST, 'as_items', [],       $SEND,    \&check_2ndpos ],
    [ $PLAYLIST, 'swapid',   [0,2],    $DISCARD, undef          ],

    # pl.moveid
    # test should come second to know the song id
    [ $PLAYLIST, 'moveid',   [0,2],    $DISCARD, undef          ],
    [ $PLAYLIST, 'as_items', [],       $SEND,    \&check_2ndpos ],
    [ $PLAYLIST, 'moveid',   [0,0],    $DISCARD, undef          ],

    # pl.swap
    [ $PLAYLIST, 'swap',     [0,2],    $DISCARD, undef          ],
    [ $PLAYLIST, 'as_items', [],       $SEND,    \&check_2ndpos ],
    [ $PLAYLIST, 'swap',     [0,2],    $DISCARD, undef          ],

    # pl.move
    [ $PLAYLIST, 'move',     [0,2],    $DISCARD, undef          ],
    [ $PLAYLIST, 'as_items', [],       $SEND,    \&check_2ndpos ],

    # pl.shuffle
    [ $MPD,      'status',   [],       $SEND,    sub { $plvers=$_[0]->data->playlist; } ],
    [ $PLAYLIST, 'shuffle',  [],       $DISCARD, undef                                  ],
    [ $MPD,      'status',   [],       $SEND,    \&check_shuffle                        ],
);

# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_shuffle {
    is( $_[0]->data->playlist, $plvers+1, 'shuffle() changes playlist version' );
}

sub check_2ndpos {
    my @items = @{ $_[0]->data };
    is( $items[2]->title, 'ok-title', 'swap[id()] / swap[id()] changes songs' );
}
