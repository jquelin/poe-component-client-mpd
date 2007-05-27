#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#

use strict;
use warnings;

use POE qw[ Component::Client::MPD::Message ];
use Readonly;
use Test::More;


my $plvers;
our $nbtests = 3;
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
    [ 'pl.clear',    [],       $DISCARD, undef        ],
    [ 'pl.add',      \@songs,  $DISCARD, undef        ],
    [ 'pl.swapid',   [0,2],    $DISCARD, undef        ],
    [ 'pl.as_items', [],       $SEND,    \&check_swap ],
    [ 'pl.swapid',   [0,2],    $DISCARD, undef        ],

    # pl.moveid
    # test should come second to know the song id

    # pl.swap
    [ 'pl.swap',     [0,2],    $DISCARD, undef        ],
    [ 'pl.as_items', [],       $SEND,    \&check_swap ],
    [ 'pl.swap',     [0,2],    $DISCARD, undef        ],

    # pl.shuffle
    [ 'status',      [],       $SEND,    sub { $plvers=$_[0]->data->playlist; } ],
    [ 'pl.shuffle',  [],       $DISCARD, undef                                  ],
    [ 'status',      [],       $SEND,    \&check_shuffle                        ],


);

# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_shuffle {
    is( $_[0]->data->playlist, $plvers+1, 'shuffle() changes playlist version' );
}

sub check_swap {
    my @items = @{ $_[0]->data };
    is( $items[2]->title, 'ok-title', 'swap[id()] changes songs' );
}
