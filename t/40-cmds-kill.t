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

use POE qw[ Component::Client::MPD ];
use Test::More;

eval 'use POE::Component::Client::MPD::Test dont_start_poe => 1';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
plan tests => 1;

POE::Component::Client::MPD->spawn( { alias => 'mpd' } );
my $id = POE::Session->create(
    inline_states => {
        _start    => \&_start,
        _check    => \&_check,
    }
);
POE::Kernel->run;
exit;

sub _start {
    my $k = $_[KERNEL];
    $k->alias_set( 'tester' );      # refcount++
    $k->post( 'mpd', 'kill' );
    $k->delay_set( '_check', 1 );
}

sub _check {
    my @procs = grep { /\smpd\s/ } grep { !/grep/ } qx[ ps -ef ];
    is( scalar @procs, 0, 'kill / disconnect shuts down mpd' );
}
