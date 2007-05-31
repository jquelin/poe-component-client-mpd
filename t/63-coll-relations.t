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

our $nbtests = 4;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # coll.albums_by_artist
    [ 'coll.albums_by_artist',  ['dir1-artist'], $SEND, \&check_albums_by_artist ],

    # coll.songs_by_artist
    [ 'coll.songs_by_artist',  ['dir1-artist'], $SEND, \&check_songs_by_artist ],
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

