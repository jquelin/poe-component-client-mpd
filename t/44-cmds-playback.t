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


our $nbtests = 19;
my @songs = qw[
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
];
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    [ $PLAYLIST, 'clear', [],      $DISCARD, undef          ],
    [ $PLAYLIST, 'add',   \@songs, $DISCARD, undef          ],

    # play
    [ $MPD, 'play',     [],      $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_play1   ],
    [ $MPD, 'play',     [2],     $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_play2   ],

    # playid
    [ $MPD, 'play',     [0],     $DISCARD, undef           ],
    [ $MPD, 'pause',    [],      $DISCARD, undef           ],
    [ $MPD, 'playid',   [],      $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_playid1 ],
    [ $MPD, 'playid',   [1],     $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_playid2 ],

    # pause
    [ $MPD, 'pause',    [1],     $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_pause1  ],
    [ $MPD, 'pause',    [0],     $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_pause2  ],
    [ $MPD, 'pause',    [],      $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_pause3  ],
    [ $MPD, 'pause',    [],      $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_pause4  ],

    # stop
    [ $MPD, 'stop',     [],      $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_stop    ],

    # prev / next
    [ $MPD, 'play',     [1],     $DISCARD, undef           ],
    [ $MPD, 'pause',    [],      $DISCARD, undef           ],
    [ $MPD, 'next',     [],      $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_prev    ],
    [ $MPD, 'prev',     [],      $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_next    ],

    # seek
    [ $MPD, 'seek',     [1,2],   $DISCARD, undef           ],
    [ $MPD, 'pause',    [1],     $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_seek1   ],
    [ $MPD, 'seek',     [],      $DISCARD, undef           ],
    [ $MPD, 'pause',    [1],     $SLEEP1,  undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_seek2   ],
    [ $MPD, 'seek',     [1],     $DISCARD, undef           ],
    [ $MPD, 'pause',    [1],     $SLEEP1,  undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_seek3   ],

    # seekid
    [ $MPD, 'seekid',   [1,1],   $DISCARD, undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_seekid1 ],
    [ $MPD, 'seekid',   [],      $DISCARD, undef           ],
    [ $MPD, 'pause',    [1],     $SLEEP1,  undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_seekid2 ],
    [ $MPD, 'seekid',   [1],     $DISCARD, undef           ],
    [ $MPD, 'pause',    [1],     $SLEEP1,  undef           ],
    [ $MPD, 'status',   [],      $SEND,    \&check_seekid3 ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
diag($@),plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

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
