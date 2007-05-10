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

use POE qw[ Component::Client::TCP ];
use Readonly;


Readonly my $IGNORE    => 0;
Readonly my $RECONNECT => 1;


#
# my $id = POE::Component::Client::MPD::Connection->spawn( \%params )
#
# This method will create a POE::Component::TCP session responsible for
# low-level communication with mpd. It will return the poe id of the
# session newly created.
#
# Arguments are passed as a hash reference, with the keys:
#   - host: hostname of the mpd server.
#   - port: port of the mpd server.
#
# Those args are not supposed to be empty - ie, there's no defaut.
#
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
            send       => \&_onprot_send,         # send data
            disconnect => \&_onprot_disconnect,   # force quit
        }
    );

    return $id;
}


#
# event: disconnect()
#
# Request the pococm-connection to be shutdown. No argument.
#
sub _onprot_disconnect {
    $_[HEAP]->{on_disconnect} = $IGNORE; # no more auto-reconnect.
    $_[KERNEL]->yield( 'shutdown' );     # shutdown socket.
}


sub _onpriv_Started {
    $_[HEAP]{mpdhub}        = $_[ARG0];
    $_[HEAP]{on_disconnect} = $RECONNECT;
}
sub _onpriv_Connected {
    my ($h) = $_[HEAP];
    $h->{incoming} = [];
    $_[KERNEL]->post( $h->{mpdhub}, '_connected' );
}

sub _onpriv_Disconnected {
    return if $_[HEAP]->{on_disconnect} != $RECONNECT;
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

POCOCM::Connection - module handling the tcp connection with mpd


=head1 DESCRIPTION

This module will spawn a poe session responsible for low-level communication
with mpd. It is written as a pococ-tcp, which is taking care of everything
needed.

Note that you're B<not> supposed to use this class directly: it's one of the
helper class for POCOCM.


=head1 PUBLIC PACKAGE METHODS

=head2 spawn( \%params )

This method will create a POE::Component::TCP session responsible for low-level
communication with mpd.

It will return the poe id of the session newly created.

You should provide some arguments as a hash reference, where the hash keys are:

=over 4

=item * host

The hostname of the mpd server.


=item * port

The port of the mpd server.


=back


Those args are not supposed to be empty - ie, there's no defaut.


=head1 PROTECTED EVENTS ACCEPTED

The following events are accepted from outside this class - but of course
restricted to POCOCM.


=head2 disconnect()

Request the pococm-connection to be shutdown. No argument.



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
