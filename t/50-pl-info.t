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


our $nbtests = 10;
my @songs = qw[
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
];
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    [ $PLAYLIST, 'clear', [],      $DISCARD, undef ],
    [ $PLAYLIST, 'add',   \@songs, $DISCARD, undef ],

    # pl.as_items
    [ $PLAYLIST, 'as_items',            [],  $SEND, \&check_as_items      ],

    # pl.items_changed_since
    [ $PLAYLIST, 'items_changed_since', [0], $SEND, \&check_items_changed ],

);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
diag($@), plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_as_items {
    my @items = @{ $_[0]->data };
    isa_ok( $_, 'Audio::MPD::Common::Item::Song',
        'pl.as_items() returns AMC::Item::Song objects' ) for @items;
    is( $items[0]->title, 'ok-title', 'first song reported first' );
}

sub check_items_changed {
    my @items = @{ $_[0]->data };
    isa_ok( $_, 'Audio::MPD::Common::Item::Song',
            'items_changed_since() returns AMC::Item::Song objects' )
        for @items;
    is( $items[0]->title, 'ok-title', 'first song reported first' );
}
