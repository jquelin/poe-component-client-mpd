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
use POE::Component::Client::MPD::Commands;
use POE::Component::Client::MPD::Connection;
use POE::Component::Client::MPD::Message;
use POE::Component::Client::MPD::Playlist;
use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors( qw[ _host _password _port  _version ] );


our $VERSION = '0.3.0';


#
# my $id = spawn( \%params )
#
# This method will create a POE session responsible for communicating
# with mpd. It will return the poe id of the session newly created.
#
# You can tune the pococm by passing some arguments as a hash reference,
# where the hash keys are:
#   - host: the hostname of the mpd server. If none given, defaults to
#     MPD_HOST env var. If this var isn't set, defaults to localhost.
#   - port: the port of the mpd server. If none given, defaults to
#     MPD_PORT env var. If this var isn't set, defaults to 6600.
#   - password: the password to sent to mpd to authenticate the client.
#     If none given, defaults to C<MPD_PASSWORD> env var. If this var
#     isn't set, defaults to empty string.
#   - alias: an optional string to alias the newly created POE session.
#
sub spawn {
    my ($type, $args) = @_;

    my $collection = POE::Component::Client::MPD::Collection->new;
    my $commands   = POE::Component::Client::MPD::Commands->new;
    my $playlist   = POE::Component::Client::MPD::Playlist->new;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            '_start'       => \&_onpriv_start,
            '_send'        => \&_onpriv_send,
            # protected events
            '_mpd_data'    => \&_onprot_mpd_data,
            '_mpd_error'   => \&_onprot_mpd_error,
            '_mpd_version' => \&_onprot_mpd_version,
            # public events
            'disconnect'   => \&_onpub_disconnect,
        },
        object_states => [
            $commands   => { # general purpose commands
                # -- MPD interaction: general commands
                # -- MPD interaction: handling volume & output
                'volume'           => '_onpub_volume',
                'output_enable'    => '_onpub_output_enable',
                'output_disable'   => '_onpub_output_disable',
                # -- MPD interaction: retrieving info from current state
                'stats'            => '_onpub_stats',
                '_stats_postback'  => '_onpriv_stats_postback',
                'status'           => '_onpub_status',
                '_status_postback' => '_onpriv_status_postback',
                'current'          => '_onpub_current',
                # -- MPD interaction: altering settings
                # -- MPD interaction: controlling playback
                'play'             => '_onpub_play',
                'playid'           => '_onpub_playid',
                'pause'            => '_onpub_pause',
                'stop'             => '_onpub_stop',
                'next'             => '_onpub_next',
            },
            $collection => { # collection related commands
                'coll.all_files'    => '_onpub_all_files',
            },
            $playlist   => { # playlist related commands
                'pl.add'            => '_onpub_add',
                'pl.delete'         => '_onpub_delete',
            },
        ],
    );

    return $session->ID;
}


#--
# public events

#
# event: disconnect()
#
# Request the pococm to be shutdown. No argument.
#
sub _onpub_disconnect {
    my ($k,$h) = @_[KERNEL, HEAP];
    $k->alias_remove( $h->{alias} ) if defined $h->{alias}; # refcount--
    $k->post( $h->{_socket}, 'disconnect' );                # pococm-conn
}


#--
# protected events.

#
# Event: _mpd_data( $msg )
#
# Received when mpd finished to send back some data.
#
sub _onprot_mpd_data {
    my $msg = $_[ARG0];
    return if $msg->_answer == $DISCARD;

    # check for post-callback.
    if ( defined $msg->_post ) {
        $_[KERNEL]->yield( $msg->_post, $msg ); # need a post-treatment...
        $msg->_post( undef );                   # remove postback.
        return;
    }

    # send result.
    $_[KERNEL]->post( $msg->_from, 'mpd_result', $msg );
}

sub _onprot_mpd_error {
    warn "mpd error\n";
}


#
# Event: _mpd_version( $vers )
#
# Event received during connection, when mpd server sends its version.
# Store it for later usage if needed.
#
sub _onprot_mpd_version {
    $_[HEAP]->{version} = $_[ARG0];
}


#--
# private events

#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
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



#
# event: _send( $msg )
#
# Event received to request message sending over tcp to mpd server.
# $msg is a pococm-message partially filled.
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
    POE::Component::Client::MPD->spawn( {
        host     => 'localhost',
        port     => 6600,
        password => 's3kr3t',  # mpd password
        alias    => 'mpd',     # poe alias
    } );

    # ... later on ...
    $_[KERNEL]->post( 'mpd', 'next' );


=head1 DESCRIPTION

POCOCM gives a clear message-passing interface (sitting on top of POE)
for talking to and controlling MPD (Music Player Daemon) servers. A
connection to the MPD server is established as soon as a new POCOCM
object is created.

Commands are then sent to the server as messages are passed.


=head1 PUBLIC PACKAGE METHODS

=head2 spawn( \%params )

This method will create a POE session responsible for communicating with mpd.
It will return the poe id of the session newly created.

You can tune the pococm by passing some arguments as a hash reference, where
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


=head1 PUBLIC EVENTS

For a list of public events that you can send to a POCOCM session, check:

=over 4

=item *

C<POCOCM::Commands> for general commands

=item *

C<POCOCM::Playlist> for playlist-related commands

=item *

C<POCOCM::Collection> for collection-related commands

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

C<POE::Component::Client::MPD development> takes place on C<< <audio-mpd
at googlegroups.com> >>: feel free to join us. (use
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
