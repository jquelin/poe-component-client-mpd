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

my $volume;
my @songs = qw[ title.ogg dir1/title-artist-album.ogg dir1/title-artist.ogg ];

our $nbtests = 5;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # store current volume.
    [ $MPD, 'status', [],   $SEND, sub { $volume = $_[0]->data->volume } ],

    # volume
    [ $MPD, 'volume', [10], $DISCARD,  undef ],  # init to sthg we know
    [ $MPD, 'volume', [42], $DISCARD,  undef ],
    [ $MPD, 'status', [],   $SEND,     \&check_volume_absolute ],

    [ $MPD, 'volume', ['+9'], $SLEEP1, undef ],
    [ $MPD, 'status', [],     $SEND,   \&check_volume_relative_pos ],

    [ $MPD, 'volume', ['-4'], $SLEEP1, undef ],
    [ $MPD, 'status', [],     $SEND,   \&check_volume_relative_neg ],

    # restore previous volume - dirty hack.
    [ $MPD, 'status', [],   $SEND, sub {$poe_kernel->post($MPD,'volume',$volume) } ],

    # output_disable.
    [ $PLAYLIST, 'add',       \@songs, $DISCARD, undef                  ],
    [ $MPD, 'play',           [],      $DISCARD, undef                  ],
    [ $MPD, 'output_disable', [0],     $SLEEP1,  undef                  ],
    [ $MPD, 'status',         [],      $SEND,    \&check_output_disable ],

    # enable_output.
    [ $MPD, 'output_enable',  [0],     $SLEEP1,  undef                  ],
    [ $MPD, 'play',           [],      $DISCARD, undef                  ],
    [ $MPD, 'pause',          [],      $DISCARD, undef                  ],
    [ $MPD, 'status',         [],      $SEND,    \&check_output_enable  ],
);

# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_volume_absolute {
    is( $_[0]->data->volume, 42, 'setting volume' );
}
sub check_volume_relative_pos {
    is( $_[0]->data->volume, 51, 'increasing volume' );
}

sub check_volume_relative_neg {
    is( $_[0]->data->volume, 47, 'decreasing volume' );
}

sub check_output_disable {
    like( $_[0]->data->error, qr/^problems/, 'disabling output' );
}

sub check_output_enable {
    is( $_[0]->data->error, undef, 'enabling output' );
}


