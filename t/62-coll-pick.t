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

my $path = 'dir1/title-artist-album.ogg';
our $nbtests = 6;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # coll.song
    [ 'coll.song',  [$path], $SEND, \&check_song ],

    # coll.songs_with_filename_partial
    [ 'coll.songs_with_filename_partial', ['album'], $SEND, \&check_song_partial ]
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;


sub check_song {
    my $song = $_[0]->data;
    isa_ok( $song, 'POE::Component::Client::MPD::Item::Song', 'song return an AMCI::Song object' );
    is( $song->file, $path, 'song return the correct song' );
    is( $song->title, 'foo-title', 'song return a full AMCI::Song' );
}

sub check_song_partial {
    my @list = @{ $_[0]->data };
    isa_ok( $_, 'POE::Component::Client::MPD::Item::Song',
            'songs_with_filename_partial return AMCI::Song objects' ) for @list;
    like( $list[0]->file, qr/album/, 'songs_with_filename_partial return the correct song' );
}


