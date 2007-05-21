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

my $volume;

our $nbtests = 8;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # repeat
    [ 'repeat', [1], $DISCARD, undef                 ],
    [ 'status', [],  $SEND,    \&check_repeat_is_on  ],
    [ 'repeat', [0], $DISCARD, undef                 ],
    [ 'status', [],  $SEND,    \&check_repeat_is_off ],
    [ 'repeat', [],  $SLEEP1,  undef                 ],
    [ 'status', [],  $SEND,    \&check_repeat_is_on  ],
    [ 'repeat', [],  $SLEEP1,  undef                 ],
    [ 'status', [],  $SEND,    \&check_repeat_is_off ],

    # random
    [ 'random', [1], $DISCARD, undef                 ],
    [ 'status', [],  $SEND,    \&check_random_is_on  ],
    [ 'random', [0], $DISCARD, undef                 ],
    [ 'status', [],  $SEND,    \&check_random_is_off ],
    [ 'random', [],  $SLEEP1,  undef                 ],
    [ 'status', [],  $SEND,    \&check_random_is_on  ],
    [ 'random', [],  $SLEEP1,  undef                 ],
    [ 'status', [],  $SEND,    \&check_random_is_off ],
);

# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_repeat_is_on  { is( $_[0]->data->repeat, 1, 'repeat is on' ); }
sub check_repeat_is_off { is( $_[0]->data->repeat, 0, 'repeat is off' ); }

sub check_random_is_on  { is( $_[0]->data->random, 1, 'random is on' ); }
sub check_random_is_off { is( $_[0]->data->random, 0, 'random is off' ); }

