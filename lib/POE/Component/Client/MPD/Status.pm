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

package POE::Component::Client::MPD::Status;

use warnings;
use strict;

use POE::Component::Client::MPD::Time;

use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors
    ( qw[ audio bitrate error playlist playlistlength random
          repeat song songid state time volume xfade ] );

#our ($VERSION) = '$Rev: 5865 $' =~ /(\d+)/;


#--
# Constructor

#
# my $status = POE::Component::Client::MPD::Status->new( \%kv )
#
# The constructor for the class POE::Component::Client::MPD::Status. %kv is
# a cooked output of what MPD server returns to the status command.
#
sub new {
    my ($class, $kv) = @_;
    my %kv = %$kv;
    $kv{time} = POE::Component::Client::MPD::Time->new( delete $kv{time} );
    bless \%kv, $class;
    return \%kv;
}

1;

__END__

=pod

=head1 NAME

POE::Component::Client::MPD::Status - class representing MPD status


=head1 SYNOPSIS

    print $status->bitrate;


=head1 DESCRIPTION

The MPD server maintains some information on its current state. Those
information can be queried with the C<status()> message of C<POCOCM>.
This method returns a C<POCOCM::Status> object, containing all
relevant information.

Note that a C<POCOCM::Status> object does B<not> update itself regularly,
and thus should be used immediately.


=head1 METHODS

=head2 Constructor

=over 4

=item new( \%kv )

The C<new()> method is the constructor for the C<POCOCM::Status> class.
It is called internally by the C<status()> message handler of C<POCOCM>,
with the result of the C<status> command sent to MPD server.

Note: one should B<never> ever instantiate an C<POCOCM::Status> object
directly - use the C<status()> message of C<POCOCM>.

=back


=head2 Accessors

Once created, one can access to the following members of the object:

=over 4

=item $status->audio()

A string with the sample rate of the song currently playing, number of bits
of the output and number of channels (2 for stereo) - separated by a colon.


=item $status->bitrate()

The instantaneous bitrate in kbps.


=item $status->error()

May appear in special error cases, such as when disabling output.


=item $status->playlist()

The playlist version number, that changes every time the playlist is updated.


=item $status->playlistlength()

The number of songs in the playlist.


=item $status->random()

Whether the playlist is read randomly or not.


=item $status->repeat()

Whether the song is repeated or not.


=item $status->song()

The offset of the song currently played in the playlist.


=item $status->songid()

The song id (MPD id) of the song currently played.


=item $status->state()

The state of MPD server. Either C<play>, C<stop> or C<pause>.


=item $status->time()

A C<POCOCM::Time> object, representing the time elapsed / remainging and
total. See the associated pod for more details.


=item $status->volume()

The current MPD volume - an integer between 0 and 100.


=item $status->xfade()

The crossfade in seconds.


=back

Please note that those accessors are read-only: changing a value will B<not>
change the current settings of MPD server. Use C<POCOCM> messages to
alter the settings.


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
