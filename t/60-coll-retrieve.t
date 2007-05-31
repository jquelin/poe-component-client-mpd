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


our $nbtests = 26;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # coll.all_items
    [ 'coll.all_items', [],       $SEND, \&check_all_items1 ],
    [ 'coll.all_items', ['dir1'], $SEND, \&check_all_items2 ],

    # coll.all_items_simple
    [ 'coll.all_items_simple', [],       $SEND, \&check_all_items_simple1 ],
    [ 'coll.all_items_simple', ['dir1'], $SEND, \&check_all_items_simple2 ],

    # coll.items_in_dir
    [ 'coll.items_in_dir', [],       $SEND, \&check_items_in_dir1 ],
    [ 'coll.items_in_dir', ['dir1'], $SEND, \&check_items_in_dir2 ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;



sub check_all_items1 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 6, 'all_items return all 6 items' );
    isa_ok( $_, 'Audio::MPD::Common::Item',
            'all_items return AMC::Item objects' ) for @list;
}

sub check_all_items2 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 3, 'all_items can be restricted to a subdir' );
    is( $list[0]->directory, 'dir1', 'all_items return a subdir first' );
    is( $list[1]->artist, 'dir1-artist', 'all_items can be restricted to a subdir' );
}

sub check_all_items_simple1 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 6, 'all_items_simple return all 6 items' );
    isa_ok( $_, 'Audio::MPD::Common::Item',
            'all_items_simple return AMC::Item objects' ) for @list;
}

sub check_all_items_simple2 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 3, 'all_items_simple can be restricted to a subdir' );
    is( $list[0]->directory, 'dir1', 'all_items_simple return a subdir first' );
    is( $list[1]->artist, undef, 'all_items_simple does not return full tags' );
}

sub check_items_in_dir1 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 4, 'items_in_dir defaults to root' );
    isa_ok( $_, 'Audio::MPD::Common::Item',
            'items_in_dir return AMC::Item objects' ) for @list;
}

sub check_items_in_dir2 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 2, 'items_in_dir can take a param' );
}
