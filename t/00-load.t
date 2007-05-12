#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin <jquelin@cpan.org>
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

use Test::More tests => 9;

BEGIN { use_ok( 'POE::Component::Client::MPD' ); }
my $version = $POE::Component::Client::MPD::VERSION;
diag( "Testing POE::Component::Client::MPD $version, Perl $], $^X" );

use_ok( 'POE::Component::Client::MPD::Item::Directory' );
use_ok( 'POE::Component::Client::MPD::Item::Playlist' );
use_ok( 'POE::Component::Client::MPD::Item::Song' );
use_ok( 'POE::Component::Client::MPD::Item' );
use_ok( 'POE::Component::Client::MPD::Message' );
use_ok( 'POE::Component::Client::MPD::Collection' );
use_ok( 'POE::Component::Client::MPD::Connection' );
use_ok( 'POE::Component::Client::MPD::Playlist' );
