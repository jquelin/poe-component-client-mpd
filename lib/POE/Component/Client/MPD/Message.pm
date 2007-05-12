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

package POE::Component::Client::MPD::Message;

use strict;
use warnings;

use Readonly;

use base qw[ Class::Accessor::Fast Exporter ];
__PACKAGE__->mk_accessors( qw[ data error request _commands _cooking _from ] );

Readonly our $RAW         => 0; # data is to be returned raw
Readonly our $AS_ITEMS    => 1; # data is to be returned as pococm-item
Readonly our $AS_KV       => 2; # data is to be returned as kv (hash)
Readonly our $STRIP_FIRST => 3; # data should have its first field stripped
our @EXPORT = qw[ $RAW $AS_ITEMS $AS_KV $STRIP_FIRST ];

#our ($VERSION) = '$Rev: 5645 $' =~ /(\d+)/;

1;

__END__

=head1 NAME

POE::Component::Client::MPD::Message - a message from POCOCM


=head1 SYNOPSIS

    print $msg->data . "\n";


=head1 DESCRIPTION

C<POCOCM::Message> is more a placeholder for a hash ref with some pre-defined
keys.


=head1 PUBLIC METHODS

This module has a C<new()> constructor, which should only be called by
one of the C<POCOCM>'s modules.

The other public methods are the following accessors:

=over 4

=item * data()

The data returned by mpd, as an array reference.


=item * error()

Set if there was some error returned by mpd. Always assured to be C<undef>
if everything went fine.


=back



=head1 SEE ALSO

You can find more information on the mpd project on its homepage at
L<http://www.musicpd.org>, or its wiki L<http://mpd.wikia.com>.

Regarding this Perl module, you can report bugs on CPAN via
L<http://rt.cpan.org/Public/Bug/Report.html?Queue=Audio-MPD>.

POE::Component::Client::MPD development takes place on
<audio-mpd@googlegroups.com>: feel free to join us.
(use L<http://groups.google.com/group/audio-mpd> to sign in). Our
subversion repository is located at L<https://svn.musicpd.org>.


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

