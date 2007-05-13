#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#

package POE::Component::Client::MPD::Stats;

use warnings;
use strict;

use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors
    ( qw[ artists albums songs uptime playtime db_playtime db_update ] );

#our ($VERSION) = '$Rev$' =~ /(\d+)/;

1;

__END__

=pod

=head1 NAME

POE::Component::Client::MPD::Stats - class representing MPD stats


=head1 SYNOPSIS

    print $stats->artists;


=head1 DESCRIPTION

The MPD server maintains some general information. Those information can be
queried with the C<stats> event of C<POCOCM>. This method fires back an
event with a C<POCOCM::Message>, which C<data()> is an C<POCOCM::Stats> object,
containing all relevant information.

Note that an C<POCOCM::Stats> object does B<not> update itself regularly,
and thus should be used immediately.


=head1 METHODS

=head2 Constructor

=over 4

=item new( %kv )

The C<new()> method is the constructor for the C<POCOCM::Status> class.
It is called internally by C<PCOCOM::Commands>, with the result of the
C<stats> command sent to MPD server.

Note: one should B<never> ever instantiate an C<POCOCM::Stats> object
directly - use the C<stats> event of C<POCOCM>.

=back


=head2 Accessors

Once created, one can access to the following members of the object:

=over 4

=item $stats->artists()

Number of artists in the music database.


=item $stats->albums()

Number of albums in the music database.


=item $stats->songs()

Number of songs in the music database.


=item $stats->uptime()

Daemon uptime (time since last startup) in seconds.


=item $stats->playtime()

Time length of music played.


=item $stats->db_playtime()

Sum of all song times in the music database.


=item $stats->db_update()

Last database update in UNIX time.


=back


Please note that those accessors are read-only: changing a value will B<not>
change the current settings of MPD server. Use C<POCOCM> events to alter
the settings.


=head1 SEE ALSO

For all related information (bug reporting, mailing-list, pointers to
MPD and POE, etc.), refer to C<POE::Component::Client::MPD>'s pod,
section C<SEE ALSO>


=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>


=head1 COPYRIGHT & LICENSE

Copyright 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut
