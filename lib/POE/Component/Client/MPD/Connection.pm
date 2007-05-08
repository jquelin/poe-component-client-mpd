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

package POE::Component::Client::MPD::Connection;

use strict;
use warnings;

use POE;


sub spawn {
    my ($type, $args) = @_;

    # connect to mpd server.
    my $id = POE::Component::Client::TCP->new(
        RemoteAddress => $args->{host},
        RemotePort    => $args->{port},
        Filter        => 'POE::Filter::Line',
        Args          => [ $args->{id} ],

        ConnectError => sub { }, # quiet errors
        ServerError  => sub { }, # quiet errors
        Started      => \&_onpriv_Started,
        Connected    => \&_onpriv_Connected,
        Disconnected => \&_onpriv_Disconnected,
        ServerInput  => \&_onpriv_ServerInput,

        InlineStates => {
            send => \&_onprot_send,        # send data
        }
    );

    return $id;
}

sub _onpriv_Started {
    $_[HEAP]{mpdhub} = $_[ARG0];
}
sub _onpriv_Connected {
    my ($h) = $_[HEAP];
    $h->{incoming} = [];
    $_[KERNEL]->post( $h->{mpdhub}, '_connected' );
}

sub _onpriv_Disconnected {
    $_[KERNEL]->yield('reconnect'); # auto-reconnect
}

sub _onpriv_ServerInput {
    my $input = $_[ARG0];
    my ($k,$h) = @_[KERNEL,HEAP];

    if ( $input eq 'OK' ) {
        $_[KERNEL]->post($h->{mpdhub}, '_got_data', $_[HEAP]->{incoming});
        $_[HEAP]->{incoming} = [];
        return;
    }
    return $k->post($h->{mpdhub}, '_got_mpd_version', $1) if $input =~ /^OK MPD (.*)$/;
    if ( $input =~ /^ACK/ ) {
        return;
    }
    push @{ $_[HEAP]{incoming} }, $input;
}

sub _onprot_send {
    $_[HEAP]->{server}->put(@_[ARG0 .. $#_]);
}



1;

__END__

=head1 NAME

POE::Component::Client::MPD::Connection - module handling the connection


=head1 DESCRIPTION


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
