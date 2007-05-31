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

our $nbtests = 14;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # coll.albums_by_artist
    [ 'coll.albums_by_artist',  ['dir1-artist'], $SEND, \&check_albums_by_artist ],

    # coll.songs_by_artist
    [ 'coll.songs_by_artist',  ['dir1-artist'], $SEND, \&check_songs_by_artist ],

    # coll.songs_by_artist_partial
    [ 'coll.songs_by_artist_partial',  ['artist'], $SEND, \&check_songs_by_artist_partial ],

    # coll.songs_from_album
    [ 'coll.songs_from_album',  ['our album'], $SEND, \&check_songs_from_album ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;


sub check_albums_by_artist {
    my @list = @{ $_[0]->data };
    is( scalar @list, 1, 'albums_by_artist return the album' );
    is( $list[0], 'our album', 'albums_by_artist return plain strings' );
}

sub check_songs_by_artist {
    my @list = @{ $_[0]->data };
    is( scalar @list, 2, 'songs_by_artist return all the songs found' );
    isa_ok( $_, 'POE::Component::Client::MPD::Item::Song',
            'songs_by_artist return AMCI::Songs' ) for @list;
    is( $list[0]->artist, 'dir1-artist', 'songs_by_artist return correct objects' );
}

sub check_songs_by_artist_partial {
    my @list = @{ $_[0]->data };
    is( scalar @list, 2, 'songs_by_artist_partial return all the songs found' );
    isa_ok( $_, 'POE::Component::Client::MPD::Item::Song',
            'songs_by_artist_partial return AMCI::Songs' ) for @list;
    like( $list[0]->artist, qr/artist/, 'songs_by_artist_partial return correct objects' );
}


sub check_songs_from_album {
    my @list = @{ $_[0]->data };
    is( scalar @list, 2, 'songs_from_album return all the songs found' );
    isa_ok( $_, 'POE::Component::Client::MPD::Item::Song',
            'songs_from_album return AMCI::Songs' ) for @list;
    is( $list[0]->album, 'our album', 'songs_from_album_partial return correct objects' );
}


