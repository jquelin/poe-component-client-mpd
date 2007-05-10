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

package POE::Component::Client::MPD;

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Collection;
use POE::Component::Client::MPD::Connection;
use POE::Component::Client::MPD::Playlist;
use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors( qw[ _host _password _port  _version ] );


our $VERSION = '0.1.0';


sub spawn {
    my ($type, $args) = @_;

    my $collection = POE::Component::Client::MPD::Collection->new;
    my $playlist   = POE::Component::Client::MPD::Playlist->new;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_start'           => \&_onpriv_start,
            '_send'            => \&_onpriv_send,
            '_got_data'        => \&_onprot_got_data,
            '_got_mpd_version' => \&_onprot_got_mpd_version,
            'disconnect'       => \&_onpub_disconnect,
        },
        object_states => [
#             $self => [
#                 '_connected',
#                 '_got_mpd_version',
#                 ],
            $collection => {
                'coll:all_files' => '_onpub_all_files',
            },
            $playlist   => {
                'pl:add'         => '_onpub_add',
                'pl:delete'      => '_onpub_delete',
            },
        ],
    );

    return $session->ID;
}


#
# event: disconnect()
#
# Request the pococm to be shutdown. No argument.
#
sub _onpub_disconnect {
    my ($k,$h) = @_[KERNEL, HEAP];
    $k->alias_remove( $h->{alias} ) if defined $h->{alias};
    $k->post( $h->{_socket}, 'disconnect' );
}


sub _onpriv_start {
    my ($h, $args) = @_[HEAP, ARG0];

    # set up connection details.
    $args = {} unless defined $args;
    my %params = (
        host     => $ENV{MPD_HOST}     || 'localhost',
        port     => $ENV{MPD_PORT}     || '6600',
        password => $ENV{MPD_PASSWORD} || '',
        %$args,                        # overwrite previous defaults
        id       => $_[SESSION]->ID,   # required for connection
    );

    # set an alias (for easier communication) if requested.
    $h->{alias} = delete $params{alias};
    $_[KERNEL]->alias_set($h->{alias}) if defined $h->{alias};

    $h->{password} = delete $params{password};
    $h->{_socket}  = POE::Component::Client::MPD::Connection->spawn(\%params);
}

=begin FIXME

#
# _connected()
#
# received when the poe::component::client::tcp is (re-)connected to the
# mpd server.
#
sub _connected {
    my ($self, $k) = @_[OBJECT, KERNEL];
    $k->post($_[HEAP]{_socket}, 'send', 'status' );
    # send password information
}

=end FIXME

=cut



sub _onprot_got_data {
    my $req = $_[ARG0];
    $_[KERNEL]->post( $req->_from, 'mpd_result', $req );
}


#
# _got_mpd_version( $vers )
#
# Event sent during connection, when mpd server sends its version.
# Store it for later usage if needed.
#
sub _onprot_got_mpd_version {
    # FIXME
    #$_[HEAP]->{version} = $_[ARG0]->answer->[0];
}


#
# {
#   from    => $id,
#   state   => $state,
#   command => [ $cmd, ... ],
# }
#
# send data over tcp to mpd server. note that $data should not be newline
# terminated (it's handled via the poe::filter).
#
sub _onpriv_send {
    $_[KERNEL]->post( $_[HEAP]->{_socket}, 'send', $_[ARG0] );
}


1;

__END__


=head1 NAME

POE::Component::Client::MPD - a full-blown mpd client library


=head1 SYNOPSIS

    use POE qw[ Component::Client::MPD ];
    POE::Component::Client::MPD->spawn(
        { host     => 'localhost',
          port     => 6600,
          password => 's3kr3t',  # mpd password
          alias    => 'mpd',     # poe alias
        }
    );

    # ... later on ...
    $_[KERNEL]->post( 'mpd', 'next' );


=head1 DESCRIPTION

POE::Component::Client::MPD is a perl mpd client, sitting on top of the POE
framework.

Audio::MPD gives a clear object-oriented interface for talking to and
controlling MPD (Music Player Daemon) servers. A connection to the MPD
server is established as soon as a new Audio::MPD object is created.
Commands are then sent to the server as the class's methods are called.




=head1 PUBLIC PACKAGE METHODS

=head2 spawn( \%params )

This method will create a POE session responsible for communicating with mpd.
It will return the poe id of the session newly created.

You can tune the pococ by passing some arguments as a hash reference, where
the hash keys are:

=over 4

=item * host

The hostname of the mpd server. If none given, defaults to C<MPD_HOST>
environment variable. If this var isn't set, defaults to C<localhost>.


=item * port

The port of the mpd server. If none given, defaults to C<MPD_PORT>
environment variable. If this var isn't set, defaults to C<6600>.


=item * password

The password to sent to mpd to authenticate the client. If none given, defaults
to C<MPD_PASSWORD> environment variable. If this var isn't set, defaults to C<>.


=item * alias

An optional string to alias the newly created POE session.


=back


=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-component-client-mpd at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-Client-MPD>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.


=head1 SEE ALSO

You can find more information on the mpd project on its homepage at
L<http://www.musicpd.org>, or its wiki L<http://mpd.wikia.com>.

POE::Component::Client::MPD development takes place on C<< <audio-mpd at
googlegroups.com> >>: feel free to join us. (use
L<http://groups.google.com/group/audio-mpd> to sign in). Our subversion
repository is located at L<https://svn.musicpd.org>.


You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-Client-MPD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-Client-MPD>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-Client-MPD>

=back



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
