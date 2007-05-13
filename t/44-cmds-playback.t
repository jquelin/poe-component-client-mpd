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


our $nbtests = 19;
my @songs = qw[
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
];
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    [ 'pl.clear', [],      $DISCARD, undef          ],
    [ 'pl.add',   \@songs, $DISCARD, undef          ],

    # play
    [ 'play',     [],      $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_play1   ],
    [ 'play',     [2],     $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_play2   ],

    # playid
    [ 'play',     [0],     $DISCARD, undef           ],
    [ 'pause',    [],      $DISCARD, undef           ],
    [ 'playid',   [],      $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_playid1 ],
    [ 'playid',   [1],     $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_playid2 ],

    # pause
    [ 'pause',    [1],     $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_pause1  ],
    [ 'pause',    [0],     $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_pause2  ],
    [ 'pause',    [],      $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_pause3  ],
    [ 'pause',    [],      $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_pause4  ],

    # stop
    [ 'stop',     [],      $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_stop    ],

    # prev / next
    [ 'play',     [1],     $DISCARD, undef           ],
    [ 'pause',    [],      $DISCARD, undef           ],
    [ 'next',     [],      $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_prev    ],
    [ 'prev',     [],      $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_next    ],

    # seek
    [ 'seek',     [1,2],   $DISCARD, undef           ],
    [ 'pause',    [1],     $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_seek1   ],
    [ 'seek',     [],      $DISCARD, undef           ],
    [ 'pause',    [1],     $SLEEP1,  undef           ],
    [ 'status',   [],      $SEND,    \&check_seek2   ],
    [ 'seek',     [1],     $DISCARD, undef           ],
    [ 'pause',    [1],     $SLEEP1,  undef           ],
    [ 'status',   [],      $SEND,    \&check_seek3   ],

    # seekid
    [ 'seekid',   [1,1],   $DISCARD, undef           ],
    [ 'status',   [],      $SEND,    \&check_seekid1 ],
    [ 'seekid',   [],      $DISCARD, undef           ],
    [ 'pause',    [1],     $SLEEP1,  undef           ],
    [ 'status',   [],      $SEND,    \&check_seekid2 ],
    [ 'seekid',   [1],     $DISCARD, undef           ],
    [ 'pause',    [1],     $SLEEP1,  undef           ],
    [ 'status',   [],      $SEND,    \&check_seekid3 ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;


sub check_play1   { is( $_[0]->data->state,  'play',  'play() starts playback' ); }
sub check_play2   { is( $_[0]->data->song,   2,       'play() can start playback at a given song' ); }
sub check_playid1 { is( $_[0]->data->state,  'play',  'playid() starts playback' ); }
sub check_playid2 { is( $_[0]->data->songid, 1,       'playid() can start playback at a given song' ); }
sub check_pause1  { is( $_[0]->data->state,  'pause', 'pause() forces playback pause' ); }
sub check_pause2  { is( $_[0]->data->state,  'play',  'pause() forces playback resume' ); }
sub check_pause3  { is( $_[0]->data->state,  'pause', 'pause() toggles to pause' ); }
sub check_pause4  { is( $_[0]->data->state,  'play',  'pause() toggles to play' ); }
sub check_stop    { is( $_[0]->data->state,  'stop',  'stop() forces full stop' ); }
sub check_prev    { is( $_[0]->data->song,   2,       'next() changes track to next one' ); }
sub check_next    { is( $_[0]->data->song,   1,       'prev() changes track to previous one' ); }
sub check_seek1 {
    my $status = $_[0]->data;
    is( $status->song,             2, 'seek() can change the current track' );
    is( $status->time->sofar_secs, 1, 'seek() seeks in the song' );
}
sub check_seek2   { is( $_[0]->data->time->sofar_secs, 0, 'seek() defaults to beginning of song' ); }
sub check_seek3   { is( $_[0]->data->time->sofar_secs, 1, 'seek() defaults to current song ' ); }
sub check_seekid1 {
    my $status = $_[0]->data;
    is( $status->songid,           1, 'seekid() can change the current track' );
    is( $status->time->sofar_secs, 1, 'seekid() seeks in the song' );
}
sub check_seekid2 { is( $_[0]->data->time->sofar_secs, 0, 'seekid() defaults to beginning of song' ); }
sub check_seekid3 { is( $_[0]->data->time->sofar_secs, 1, 'seekid() defaults to current song' ); }
