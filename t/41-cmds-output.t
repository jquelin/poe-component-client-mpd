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

my $volume;
my @songs = qw[ title.ogg dir1/title-artist-album.ogg dir1/title-artist.ogg ];

our $nbtests = 5;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # store current volume.
    [ 'status', [],   $SEND, sub { $volume = $_[0]->data->volume } ],

    # volume
    [ 'volume', [10], $DISCARD,  undef ],  # init to sthg we know
    [ 'volume', [42], $DISCARD,  undef ],
    [ 'status', [],   $SEND,     \&check_volume_absolute ],

    [ 'volume', ['+9'], $SLEEP1, undef ],
    [ 'status', [],     $SEND,   \&check_volume_relative_pos ],

    [ 'volume', ['-4'], $SLEEP1, undef ],
    [ 'status', [],     $SEND,   \&check_volume_relative_neg ],

    # restore previous volume - dirty hack.
    [ 'status', [],   $SEND, sub {$poe_kernel->post('mpd','volume',$volume) } ],

    # output_disable.
    [ 'pl.add',         \@songs, $DISCARD, undef                  ],
    [ 'play',           [],      $DISCARD, undef                  ],
    [ 'output_disable', [0],     $SLEEP1,  undef                  ],
    [ 'status',         [],      $SEND,    \&check_output_disable ],

    # enable_output.
    [ 'output_enable',  [0],     $SLEEP1,  undef                  ],
    [ 'play',           [],      $DISCARD, undef                  ],
    [ 'pause',          [],      $DISCARD, undef                  ],
    [ 'status',         [],      $SEND,    \&check_output_enable  ],
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


