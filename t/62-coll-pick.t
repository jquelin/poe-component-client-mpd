#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;

use Test::More;

my $path    = 'dir1/title-artist-album.ogg';
my $nbtests = 8;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # song
    [ 'coll.song',                          [$path], 0, \&check_song         ],

    # songs_with_filename_partial
    [ 'coll.songs_with_filename_partial', ['album'], 0, \&check_song_partial ],
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

sub check_song {
    my ($msg, $song) = @_;
    check_success($msg);
    isa_ok($song, 'Audio::MPD::Common::Item::Song', 'song() return');
    is($song->file, $path, 'song() return the correct song');
    is($song->title, 'foo-title', 'song() return a full AMCI::Song');
}

sub check_song_partial {
    my ($msg, $items) = @_;
    check_success($msg);
    isa_ok($_, 'Audio::MPD::Common::Item::Song', 'songs_with_filename_partial() return') for @$items;
    like($items->[0]->file, qr/album/, 'songs_with_filename_partial() return the correct song');
}


