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


our $nbtests = 10;
my @songs = qw[
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
];
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    [ 'pl.clear', [],      $DISCARD, undef ],
    [ 'pl.add',   \@songs, $DISCARD, undef ],

    # pl.as_items
    [ 'pl.as_items',            [],  $SEND, \&check_as_items      ],

    # pl.items_changed_since
    [ 'pl.items_changed_since', [0], $SEND, \&check_items_changed ],

);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_as_items {
    my @items = @{ $_[0]->data };
    isa_ok( $_, 'POE::Component::Client::MPD::Item::Song',
        'pl.as_items() returns POCOCM::Item::Song objects' ) for @items;
    is( $items[0]->title, 'ok-title', 'first song reported first' );
}

sub check_items_changed {
    my @items = @{ $_[0]->data };
    isa_ok( $_, 'POE::Component::Client::MPD::Item::Song',
            'items_changed_since() returns POCOCM::Item::Song objects' )
        for @items;
    is( $items[0]->title, 'ok-title', 'first song reported first' );
}
