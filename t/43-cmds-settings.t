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
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # repeat
    [ $MPD, 'repeat', [1],  $DISCARD, undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_repeat_is_on  ],
    [ $MPD, 'repeat', [0],  $DISCARD, undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_repeat_is_off ],
    [ $MPD, 'repeat', [],   $SLEEP1,  undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_repeat_is_on  ],
    [ $MPD, 'repeat', [],   $SLEEP1,  undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_repeat_is_off ],

    # random
    [ $MPD, 'random', [1],  $DISCARD, undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_random_is_on  ],
    [ $MPD, 'random', [0],  $DISCARD, undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_random_is_off ],
    [ $MPD, 'random', [],   $SLEEP1,  undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_random_is_on  ],
    [ $MPD, 'random', [],   $SLEEP1,  undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_random_is_off ],

    # fade
    [ $MPD, 'fade',   [15], $DISCARD, undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_fade_is_on    ],
    [ $MPD, 'fade',   [],   $DISCARD, undef                 ],
    [ $MPD, 'status', [],   $SEND,    \&check_fade_is_off   ],
);

# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_repeat_is_on  { is( $_[0]->data->repeat, 1, 'repeat is on' ); }
sub check_repeat_is_off { is( $_[0]->data->repeat, 0, 'repeat is off' ); }

sub check_random_is_on  { is( $_[0]->data->random, 1, 'random is on' ); }
sub check_random_is_off { is( $_[0]->data->random, 0, 'random is off' ); }

sub check_fade_is_on    { is( $_[0]->data->xfade, 15, 'enabling fading' ); }
sub check_fade_is_off   { is( $_[0]->data->xfade, 0, 'disabling fading by default' ); }

