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


our $nbtests = 9;
my @songs = qw[ title.ogg dir1/title-artist-album.ogg dir1/title-artist.ogg ];
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

#     [ 'updatedb', [],      $DISCARD, \&check_stats  ],
#     [ 'pl.add',   \@songs, $DISCARD, \&check_stats  ],
    [ 'stats',    [],      $SEND,    \&check_stats  ],

#     [ 'play',   [], $DISCARD, undef          ],
#     [ 'pause',  [], $DISCARD, undef          ],
    [ 'status', [], $SEND,    \&check_status ],

);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;


sub check_stats {
    my $stats = $_[0]->data;
    isa_ok( $stats, 'POE::Component::Client::MPD::Stats',
            'stats() returns a pococm::stats object' );
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
    isa_ok( $status, 'POE::Component::Client::MPD::Status',
            'status return a pococm::status object' );
}


__END__

#
# testing current song.
$song = $mpd->current;
isa_ok( $song, 'Audio::MPD::Item::Song', 'current return an Audio::MPD::Item::Song object' );


#
# testing song.
$song = $mpd->song(1);
isa_ok( $song, 'Audio::MPD::Item::Song', 'song() returns an Audio::MPD::Item::Song object' );
is( $song->file, 'dir1/title-artist-album.ogg', 'song() returns the wanted song' );
$song = $mpd->song; # default to current song
is( $song->file, 'title.ogg', 'song() defaults to current song' );


#
# testing songid.
$song = $mpd->songid(1);
isa_ok( $song, 'Audio::MPD::Item::Song', 'songid() returns an Audio::MPD::Item::Song object' );
is( $song->file, 'dir1/title-artist-album.ogg', 'songid() returns the wanted song' );
$song = $mpd->songid; # default to current song
is( $song->file, 'title.ogg', 'songid() defaults to current song' );


exit;
