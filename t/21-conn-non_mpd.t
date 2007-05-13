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

use POE qw[ Component::Client::MPD::Connection ];
use Readonly;
use Test::More;

my $sendmail_running = grep { /:25\s.*LISTEN/ } qx[ netstat -an ];
plan skip_all => 'need some sendmail server running' unless $sendmail_running;

plan tests => 1;

Readonly my $ALIAS => 'tester';

my $id = POE::Session->create(
    inline_states => {
        _start     => \&_onpriv_start,
        _mpd_error => \&_onpriv_mpd_error,
    }
);
my $conn = POE::Component::Client::MPD::Connection->spawn( {
    host => 'localhost',
    port => 25,
    id   => $id,
} );
POE::Kernel->run;
exit;


sub _onpriv_start {
    $_[KERNEL]->alias_set($ALIAS); # increment refcount
}

sub _onpriv_mpd_error  {
    my $k = $_[KERNEL];
    like( $_[ARG0]->error, qr/^Not a mpd server - welcome string was:/, 'wrong server');
    $k->alias_remove($ALIAS); # increment refcount
    $k->post( $conn, 'disconnect' );
}

