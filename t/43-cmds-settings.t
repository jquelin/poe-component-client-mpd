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

my $nbtests = 30;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # repeat
    [ 'repeat', [1],  0, \&check_success       ],
    [ 'status', [],   0, \&check_repeat_is_on  ],
    [ 'repeat', [0],  0, \&check_success       ],
    [ 'status', [],   0, \&check_repeat_is_off ],
    [ 'repeat', [],   1, \&check_success       ],
    [ 'status', [],   0, \&check_repeat_is_on  ],
    [ 'repeat', [],   1, \&check_success       ],
    [ 'status', [],   0, \&check_repeat_is_off ],

    # fade
    [ 'fade',   [15], 0, \&check_success       ],
    [ 'status', [],   0, \&check_fade_is_on    ],
    [ 'fade',   [],   0, \&check_success       ],
    [ 'status', [],   0, \&check_fade_is_off   ],

    # random
    [ 'random', [1],  0, \&check_success       ],
    [ 'status', [],   0, \&check_random_is_on  ],
    [ 'random', [0],  0, \&check_success       ],
    [ 'status', [],   0, \&check_random_is_off ],
    [ 'random', [],   1, \&check_success       ],
    [ 'status', [],   0, \&check_random_is_on  ],
    [ 'random', [],   1, \&check_success       ],
    [ 'status', [],   0, \&check_random_is_off ],
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

sub check_repeat_is_on  { check_success($_[0]); is($_[1]->repeat, 1, 'repeat is on'); }
sub check_repeat_is_off { check_success($_[0]); is($_[1]->repeat, 0, 'repeat is off'); }

sub check_random_is_on  { check_success($_[0]); is($_[1]->random, 1, 'random is on'); }
sub check_random_is_off { check_success($_[0]); is($_[1]->random, 0, 'random is off'); }

sub check_fade_is_on    { check_success($_[0]); is($_[1]->xfade, 15, 'enabling fading'); }
sub check_fade_is_off   { check_success($_[0]); is($_[1]->xfade, 0,  'disabling fading by default'); }

