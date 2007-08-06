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


my @songs = qw[
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
];
my ($nb);
our $nbtests = 5;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # delete / deleteid
    # should come first to be sure songid #0 is really here.
    [ $PLAYLIST, 'clear',    [],      $DISCARD, undef         ],
    [ $PLAYLIST, 'add',      \@songs, $DISCARD, undef         ],
    [ $MPD,      'status',   [],      $SEND,    \&get_nb      ],
    [ $PLAYLIST, 'delete',   [1,2],   $DISCARD, undef         ],
    [ $MPD,      'status',   [],      $SEND,    \&check_del   ],
    [ $MPD,      'status',   [],      $SEND,    \&get_nb      ],
    [ $PLAYLIST, 'deleteid', [0],     $DISCARD, undef         ],
    [ $MPD,      'status',   [],      $SEND,    \&check_delid ],

    # add
    [ $PLAYLIST, 'clear',    [],              $DISCARD, undef       ],
    [ $MPD,      'status',   [],              $SEND,    \&get_nb    ],
    [ $PLAYLIST, 'add',      [ 'title.ogg' ], $DISCARD, undef       ],
    [ $PLAYLIST, 'add',      \@songs,         $DISCARD, undef       ],
    [ $MPD,      'status',   [],              $SEND,    \&check_add ],

    # clear
    [ $PLAYLIST, 'add',   \@songs, $DISCARD, undef         ],
    [ $PLAYLIST, 'clear', [],      $DISCARD, undef         ],
    [ $MPD,      'status',   [],      $SEND,    \&check_clear ],

    # crop
    [ $PLAYLIST, 'add',  \@songs, $DISCARD, undef        ],
    [ $MPD,      'play',    [1],     $DISCARD, undef        ], # to set song
    [ $MPD,      'stop',    [],      $DISCARD, undef        ],
    [ $PLAYLIST, 'crop', [],      $SLEEP1,  undef        ],
    [ $MPD,      'status',   [],     $SEND,    \&check_crop ],

);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub get_nb      { $nb = $_[0]->data->playlistlength }
sub check_add   { is( $_[0]->data->playlistlength, $nb+5, 'add() songs' ); }
sub check_del   { is( $_[0]->data->playlistlength, $nb-2, 'delete() songs' ); }
sub check_delid { is( $_[0]->data->playlistlength, $nb-1, 'deleteid() songs' ); }
sub check_clear { is( $_[0]->data->playlistlength, 0, 'clear() leaves 0 song' ); }
sub check_crop  { is( $_[0]->data->playlistlength, 1, 'crop() leaves only 1 song' ); }
