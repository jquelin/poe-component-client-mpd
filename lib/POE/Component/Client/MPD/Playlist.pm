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

package POE::Component::Client::MPD::Playlist;

use strict;
use warnings;

use POE;
use base qw[ Class::Accessor::Fast ];


#
# event: pl:add( $path, $path, ... )
#
# Add the songs identified by $path (relative to MPD's music directory) to
# the current playlist.
# No return event.
#
sub _onpub_add {
    my @pathes   = @_[ARG0 .. $#_];    # args of the poe event
    my @commands = (                   # build the commands
        'command_list_begin',
        map( qq[add "$_"], @pathes ),
        'command_list_end',
    );

    # send the commands to mpd.
    my $args = {
        from     => $_[SENDER]->ID,
        state    => $_[STATE],
        commands => \@commands
    };
    $_[KERNEL]->yield( '_send', $args );
}


#
# event: pl:delete( $number, $number, ... )
#
# Remove song $number (starting from 0) from the current playlist.
# No return event.
#
sub _onpub_delete {
    my @numbers  = @_[ARG0 .. $#_];    # args of the poe event
    my @commands = (                   # build the commands
        'command_list_begin',
        map( qq[delete $_], reverse sort {$a<=>$b} @numbers ),
        'command_list_end',
    );

    # send the commands to mpd.
    my $args = {
        from     => $_[SENDER]->ID,
        state    => $_[STATE],
        commands => \@commands
    };
    $_[KERNEL]->yield( '_send', $args );
}


1;

__END__

=head1 NAME

POE::Component::Client::MPD::Playlist - module handling playlist commands


=head1 DESCRIPTION

C<POCOCM::Playlist> is responsible for handling playlist-related commands.
To achieve those commands, send the corresponding event to the POCOCM
session you created: it will be responsible for dispatching the event
where it is needed.


=head1 PUBLIC EVENTS

The following is a list of general purpose events accepted by POCOCM.


=head2 Retrieving information

=head2 Adding / removing songs

=head2 Changing playlist order

=head2 Managing playlists


=head1 SEE ALSO

You can find more information on the mpd project on its homepage at
L<http://www.musicpd.org>, or its wiki L<http://mpd.wikia.com>.

Regarding this Perl module, you can report bugs on CPAN via
L<http://rt.cpan.org/Public/Bug/Report.html?Queue=Audio-MPD>.

POE::Component::Client::MPD development takes place on
<audio-mpd@googlegroups.com>: feel free to join us.
(use L<http://groups.google.com/group/audio-mpd> to sign in). Our subversion
repository is located at L<https://svn.musicpd.org>.


=head1 AUTHOR

Jerome Quelin <jquelin@cpan.org>


=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007 Jerome Quelin <jquelin@cpan.org>


This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
