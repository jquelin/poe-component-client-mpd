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

sub POE::Kernel::TRACE_EVENTS () { 1 }
use POE;
use POE::Component::Client::MPD::Message;
use Readonly;
use Test::More;


our $nbtests = 3;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # updatedb
    [ 'updatedb', [],       $SLEEP1,  undef           ],
    [ 'stats',    [],       $SEND,    \&check_update  ],
    [ 'updatedb', ['dir1'], $DISCARD, undef           ],
    [ 'stats',    [],       $SEND,    \&check_update  ],

    # version
    # needs to be *after* updatedb, so version messages can be treated.
    [ 'version',  [],       $SEND,    \&check_version ],
);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
diag($@), plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_version {
    SKIP: {
        my $output = qx[mpd --version 2>/dev/null];
        skip 'need mpd installed', 1 unless $output =~ /^mpd .* ([\d.]+)\n/;
        is( $_[0]->data, $1, 'mpd version grabbed during connection' );
    }
}
sub check_update  {
    my $stats = $_[0]->data;
    isnt( $stats->db_update,  0, 'database has been updated' );
}

