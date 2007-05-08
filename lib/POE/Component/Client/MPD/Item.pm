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

package POE::Component::Client::MPD::Item;

use strict;
use warnings;
use POE::Component::Client::MPD::Item::Directory;
use POE::Component::Client::MPD::Item::Song;

#our ($VERSION) = '$Rev: 5645 $' =~ /(\d+)/;

#
# constructor.
#
sub new {
    my ($pkg, %params) = @_;

    # transform keys in lowercase.
    my %lowcase;
    @lowcase{ map { lc } keys %params } = values %params;

    my $item = exists $params{file} ?
        POE::Component::Client::MPD::Item::Song->new(\%lowcase) :
        POE::Component::Client::MPD::Item::Directory->new(\%lowcase);
    return $item;
}

1;

__END__


=head1 NAME

POE::Component::Client::MPD::Item - a generic collection item


=head1 SYNOPSIS

    my $item = POE::Component::Client::MPD::Item->new( %params );


=head1 DESCRIPTION

C<POE::Component::Client::MPD::Item> is a virtual class representing a generic
item of mpd's collection. It can be either a song or a directory. Depending on
the params given to C<new>, it will create and return an
C<POE::Component::Client::MPD::Item::Song> or an
C<POE::Component::Client::MPD::Item::Directory> object. Currently, the
discrimination is done on the existence of the C<file> key of C<%params>.


=head1 PUBLIC METHODS

Note that the only sub worth it in this class is the constructor:

=over 4

=item new( key => val [, key => val [, ...] ] )

Create and return either an C<POE::Component::Client::MPD::Item::Song> or an
C<POE::Component::Client::MPD::Item::Directory> object.

=back


=head1 SEE ALSO

You can find more information on the mpd project on its homepage at
L<http://www.musicpd.org>, or its wiki L<http://mpd.wikia.com>.

Regarding this Perl module, you can report bugs on CPAN via
L<http://rt.cpan.org/Public/Bug/Report.html?Queue=Audio-MPD>.

POE::Component::Client::MPD development takes place on
<audio-mpd@googlegroups.com>: feel free to join us.
(use L<http://groups.google.com/group/audio-mpd> to sign in). Our subversion
repository is located at L<https://svn.musicpd.org>.


=head1 AUTHORS

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
