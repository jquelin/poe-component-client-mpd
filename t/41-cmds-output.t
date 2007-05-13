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
plan skip_all => 'need some mpd commands';
__END__


our $nbtests = 2;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    [ 'volume', [10], $DISCARD, undef ],  # init to sthg we know
    [ 'volume', [42], $DISCARD, undef ],
    #[ 'status', [],   $SEND,    \&check_volume_absolute ],

    [ 'volume', ['+9'], $DISCARD, undef ],
    #[ 'status', [],     $SEND,    \&check_volume_relative_pos ],

    [ 'volume', ['-4'], $DISCARD, undef ],
    #[ 'status', [],     $SEND,    \&check_volume_relative_neg ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;



sub check_volume_absolute {
    #is( $mpd->status->volume, 42, 'setting volume' );
}
sub check_volume_telative_pos {
    #is( $mpd->status->volume, 51, 'setting volume' );
}

sub check_volume_telative_neg {
    #is( $mpd->status->volume, 47, 'decreasing volume' );
}

__END__



#
# testing disable_output.
$mpd->playlist->add( 'title.ogg' );
$mpd->playlist->add( 'dir1/title-artist-album.ogg' );
$mpd->playlist->add( 'dir1/title-artist.ogg' );
$mpd->play;
$mpd->output_disable(0);
sleep(1);
like( $mpd->status->error, qr/^problems/, 'disabling output' );

#
# testing enable_output.
$mpd->output_enable(0);
sleep(1);
$mpd->play; $mpd->pause;
is( $mpd->status->error, undef, 'enabling output' );


