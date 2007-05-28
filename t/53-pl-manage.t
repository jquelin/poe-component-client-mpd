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


our $nbtests = 5;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # pl.load
    [ 'pl.load',     ['test'], $DISCARD, undef        ],
    [ 'pl.as_items', [],       $SEND,    \&check_load ],

);

# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_load {
    my @items = @{ $_[0]->data };
    is( scalar @items, 1, 'load() adds songs' );
    is( $items[0]->title, 'ok-title', 'load() adds the correct songs' );
}
