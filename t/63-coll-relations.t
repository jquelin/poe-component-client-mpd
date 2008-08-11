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

use Test::More;

my $nbtests = 33;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # albums_by_artist
    [ 'coll.albums_by_artist',         ['dir1-artist'], 0, \&check_albums_by_artist         ],

    # songs_by_artist
    [ 'coll.songs_by_artist',          ['dir1-artist'], 0, \&check_songs_by_artist          ],

    # songs_by_artist_partial
    [ 'coll.songs_by_artist_partial',       ['artist'], 0, \&check_songs_by_artist_partial  ],

    # songs_from_album
    [ 'coll.songs_from_album',           ['our album'], 0, \&check_songs_from_album         ],

    # songs_from_album_partial
    [ 'coll.songs_from_album_partial',       ['album'], 0, \&check_songs_from_album_partial ],

    # songs_with_title
    [ 'coll.songs_with_title',            ['ok-title'], 0, \&check_songs_with_title         ],

    # songs_with_title_partial
    [ 'coll.songs_with_title_partial',       ['title'], 0, \&check_songs_with_title_partial ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test nbtests=>$nbtests, tests=>\@tests';
diag($@), plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

#--

sub check_success {
    my ($msg) = @_;
    is($msg->status, 1, "command '" . $msg->request . "' returned an ok status");
}

sub check_albums_by_artist {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 1, 'albums_by_artist() return the album');
    is($items->[0], 'our album', 'albums_by_artist() return plain strings');
}

sub check_songs_by_artist {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 2, 'songs_by_artist() return all the songs found' );
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'songs_by_artist() return') for @$items;
    is($items->[0]->artist, 'dir1-artist', 'songs_by_artist() return correct objects');
}

sub check_songs_by_artist_partial {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 2, 'songs_by_artist_partial() return all the songs found');
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'songs_by_artist_partial() return') for @$items;
    like($items->[0]->artist, qr/artist/, 'songs_by_artist_partial() return correct objects');
}


sub check_songs_from_album {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 2, 'songs_from_album() return all the songs found');
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'songs_from_album() return') for @$items;
    is($items->[0]->album, 'our album', 'songs_from_album() return correct objects' );
}

sub check_songs_from_album_partial {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 2, 'songs_from_album_partial() return all the songs found' );
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'songs_from_album_partial() return') for @$items;
    like($items->[0]->album, qr/album/, 'songs_from_album_partial() return correct objects');
}

sub check_songs_with_title {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 1, 'songs_with_title() return all the songs found');
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'songs_with_title() return') for @$items;
    is($items->[0]->title, 'ok-title', 'songs_with_title() return correct objects');
}

sub check_songs_with_title_partial {
    my ($msg, $items) = @_;
    check_success($msg);
    is(scalar @$items, 3, 'songs_with_title_partial() return all the songs found');
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'songs_with_title_partial() return') for @$items;
    like($items->[0]->title, qr/title/, 'songs_with_title_partial() return correct objects');
}

