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

my @songs   = qw{ title.ogg dir1/title-artist-album.ogg dir1/title-artist.ogg };
my $nbtests = 20;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # volume
    [ 'volume', [10], 0,  \&check_success                  ],  # init to sthg we know
    [ 'volume', [4],  0,  \&check_success                  ],
    [ 'status', [],   0,  \&check_volume_absolute          ],

    [ 'volume', ['+5'], 1, \&check_success                 ],
    [ 'status', [],     0, \&check_volume_relative_pos     ],

    [ 'volume', ['-4'], 1, \&check_success                 ],
    [ 'status', [],     0, \&check_volume_relative_neg     ],

    # output_disable.
    [ 'pl.add',         \@songs, 0, \&check_success        ],
    [ 'play',           [],      0, \&check_success        ],
    [ 'output_disable', [0],     1, \&check_success        ],
    [ 'status',         [],      0, \&check_output_disable ],

    # enable_output.
    [ 'output_enable',  [0],     1, \&check_success        ],
    [ 'play',           [],      0, \&check_success        ],
    [ 'pause',          [],      0, \&check_success        ],
    [ 'status',         [],      0, \&check_output_enable  ],
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

sub check_volume_absolute {
    my ($msg, $status) = @_;
    check_success($msg);
    is($status->volume, 4, 'setting volume');
}

sub check_volume_relative_pos {
    my ($msg, $status) = @_;
    check_success($msg);
    is($status->volume, 9, 'increasing volume');
}

sub check_volume_relative_neg {
    my ($msg, $status) = @_;
    check_success($msg);
    is($status->volume, 5, 'decreasing volume');
}

sub check_output_disable {
    my ($msg, $status) = @_;
    check_success($msg);
    TODO: {
        local $TODO = "detection method doesn't always work - depends on timing";
        like($status->error, qr/^problems/, 'disabling output' );
    }
}

sub check_output_enable {
    my ($msg, $status) = @_;
    check_success($msg);
    is($status->error, undef, 'enabling output' );
}


