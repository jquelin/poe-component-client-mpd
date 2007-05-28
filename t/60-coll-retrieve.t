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


our $nbtests = 10;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # coll.all_items
    [ 'coll.all_items', [],       $SEND, \&check_all_items1 ],
    [ 'coll.all_items', ['dir1'], $SEND, \&check_all_items2 ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;



sub check_all_items1 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 6, 'all_items return all 6 items' );
    isa_ok( $_, 'POE::Component::Client::MPD::Item',
            'all_items return AMI objects' ) for @list;
}

sub check_all_items2 {
    my @list = @{ $_[0]->data };
    is( scalar @list, 3, 'all_items can be restricted to a subdir' );
    is( $list[0]->directory, 'dir1', 'all_items return a subdir first' );
    is( $list[1]->artist, 'dir1-artist', 'all_items can be restricted to a subdir' );
}

