#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD;

use 5.010;
use strict;
use warnings;

use Audio::MPD::Common::Stats;
use Audio::MPD::Common::Status;
use Carp;
use List::MoreUtils qw[ firstidx ];
use POE;
use POE::Component::Client::MPD::Commands;
#use POE::Component::Client::MPD::Collection;
use POE::Component::Client::MPD::Connection;
use POE::Component::Client::MPD::Message;
use POE::Component::Client::MPD::Playlist;

use base qw{ Class::Accessor::Fast };

our $VERSION = '0.8.1';

#--
# CLASS METHODS
#

# -- public methods

#
# my $id = POE::Component::Client::MPD->spawn( \%params )
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

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            '_start'             => \&_onpriv_start,
            # protected events
            #'mpd_connect_error_fatal'     => \&_onprot_conn_connect_error_fatal,
            #'mpd_connect_error_retriable' => \&_onprot_conn_connect_error_retriable,
            'mpd_connected'               => \&_onprot_mpd_connected,
            'mpd_disconnected'            => \&_onprot_mpd_disconnected,
            'mpd_data'      =>  \&_onprot_mpd_data,
            'mpd_error'     =>  \&_onprot_conn_error,
            # public events
            'disconnect'     => \&_onpub_disconnect,
            '_default'       => \&POE::Component::Client::MPD::_onpub_default,

            '_mpd_data'      => \&_onprot_mpd_data,
            '_mpd_error'     => \&_onprot_mpd_error,
            '_mpd_version'   => \&_onprot_mpd_version,
            '_version'       => \&_onprot_version,
        },
    );
    return $session->ID;
}


#--
# METHODS
#

# -- private methods

sub _dispatch {
    my ($self, $k, $h, $event, $msg) = @_;

    # dispatch the event.
    given ($event) {
        # playlist commands
        when (/^pl\.(.*)$/) {
        }

        # collection commands
        when (/^coll\.(.*)$/) {
        }

        # basic commands
        default {
            my $meth = "_do_$event";
            $h->{cmds}->$meth($k, $h, $msg);
        }
    }
}


#--
# EVENTS HANDLERS
#

# -- public events.

#
# catch-all handler.
#
sub _onpub_default {
    my ($k, $h, $event, $params) = @_[KERNEL, HEAP, ARG0, ARG1];

    # check if event is handled.
    my @ok_events_commands = qw{
        version kill updatedb urlhandlers
        volume
        stats status
        play
    };
    my @ok_events_playlist = qw{
    };
    my @ok_events = ( @ok_events_commands, @ok_events_playlist );
    return unless $event ~~ [ @ok_events ];

    # create the message that will hold
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from       => $_[SENDER]->ID,
        request    => $event,  # /!\ $_[STATE] eq 'default'
        params     => $params,
        #_answer    => <to be set by handler>
        #_commands  => <to be set by handler>
        #_cooking   => <to be set by handler>
        #_transform => <to be set by handler>
        #_post      => <to be set by handler>
    } );

    # dispatch the event so it is handled by the correct object/method.
    $h->{mpd}->_dispatch($k, $h, $event, $msg);
}


#
# event: disconnect()
#
# Request the pococm to be shutdown. Leave mpd running.
#
sub _onpub_disconnect {
    my ($k,$h) = @_[KERNEL, HEAP];
    $k->alias_remove( $h->{alias} ) if defined $h->{alias}; # refcount--
    $k->post( $h->{socket}, 'disconnect' );                 # pococm-conn
}


# -- protected events.

#
# event: mpd_connected($version)
#
# Called when pococm-conn made sure we're talking to a mpd server.
#
sub _onprot_mpd_connected {
    my ($k, $h, $version) = @_[KERNEL, HEAP, ARG0];
    $h->{version} = $version;
    # FIXME: send password information to mpd
    # FIXME: send status information to peer
}



#
# event: mpd_disconnected()
#
# Called when pococm-conn got disconnected by mpd.
#
sub _onprot_mpd_disconnected {
    my ($k, $h, $version) = @_[KERNEL, HEAP, ARG0];
}



#
# Event: mpd_data( $msg )
#
# Received when mpd finished to send back some data.
#
sub _onprot_mpd_data {
    my ($k, $h, $msg) = @_[KERNEL, HEAP, ARG0];

    # transform data if needed.
    given ($msg->_transform) {
        when ($AS_SCALAR) {
            my $data = $msg->_data->[0];
            $msg->_data($data);
        }
        when ($AS_STATS) {
            my %stats = @{ $msg->_data };
            my $stats = Audio::MPD::Common::Stats->new( \%stats );
            $msg->_data($stats);
        }
        when ($AS_STATUS) {
            my %status = @{ $msg->_data };
            my $status = Audio::MPD::Common::Status->new( \%status );
            $msg->_data($status);
        };
    }


    # check for post-callback.
    if ( defined $msg->_post ) {
        my $event = $msg->_post;    # save postback.
        $msg->_post( undef );       # remove postback.
        $h->{mpd}->_dispatch($k, $h, $event, $msg);
        return;
    }

=pod

    # check for pre-callback.
    my $preidx = firstidx { $msg->_request eq $_->_pre_event } @{ $h->{pre_messages} };
    if ( $preidx != -1 ) {
        my $pre = splice @{ $h->{pre_messages} }, $preidx, 1;
        $k->yield( $pre->_pre_from, $pre, $msg );  # call post pre-event
        $pre->_pre_from ( undef );                 # remove pre-callback
        $pre->_pre_event( undef );                 # remove pre-event
        return;
    }

    return if $msg->_answer == $DISCARD;

=cut

    # send result.
    $k->post($msg->_from, 'mpd_result', $msg, $msg->_data);
}


=pod

sub _onprot_mpd_error {
    # send error.
    my $msg = $_[ARG0];
    $_[KERNEL]->post( $msg->_from, 'mpd_error', $msg );
}

=cut

=pod

#
# Event: _mpd_version( $vers )
#
# Event received during connection, when mpd server sends its version.
# Store it for later usage if needed.
#
sub _onprot_mpd_version {
    $_[HEAP]->{version} = $_[ARG0];
}

=cut


# -- private events

#
# Event: _start( \%params )
#
# Called when the poe session gets initialized. Receive a reference
# to %params, same as spawn() received.
#
sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];

    # set up connection details.
    $args = {} unless defined $args;
    my %params = (
        host     => $ENV{MPD_HOST}     // 'localhost',
        port     => $ENV{MPD_PORT}     // '6600',
        password => $ENV{MPD_PASSWORD} // '',
        %$args,                        # overwrite previous defaults
        id       => $_[SESSION]->ID,   # required for connection
    );

    # set an alias (for easier communication) if requested.
    $h->{alias} = delete $params{alias};
    $k->alias_set($h->{alias}) if defined $h->{alias};

    $h->{password} = delete $params{password};
    $h->{socket}   = POE::Component::Client::MPD::Connection->spawn(\%params);

    $h->{mpd}      = POE::Component::Client::MPD->new;
    $h->{cmds}     = POE::Component::Client::MPD::Commands->new;
    $h->{playlist} = POE::Component::Client::MPD::Playlist->new;
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


=pod

#
# event: _send( $msg )
#
# Event received to request message sending over tcp to mpd server.
# $msg is a pococm-message partially filled.
#
sub _onpriv_send {
    my ($k, $h, $msg) = @_[KERNEL, HEAP, ARG0];
    if ( defined $msg->_pre_event ) {
        $k->yield( $msg->_pre_event );        # fire wanted pre-event
        push @{ $h->{pre_messages} }, $msg;   # store message
        return;
    }
    $k->post( $_[HEAP]->{_socket}, 'send', $msg );
}

=cut


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

Copyright (c) 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
