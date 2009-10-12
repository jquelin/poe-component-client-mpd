#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.
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
use POE;
use POE::Component::Client::MPD::Commands;
use POE::Component::Client::MPD::Collection;
use POE::Component::Client::MPD::Connection;
use POE::Component::Client::MPD::Message;
use POE::Component::Client::MPD::Playlist;

use base qw{ Class::Accessor::Fast };

our $VERSION = '0.9.3';


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
#   - status_msgs_to: session to whom to send connection status.
#     optional (although recommended), no default.
#
sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            # private events
            '_start'         => \&_onpriv_start,
            # protected events
            'mpd_connect_error_fatal'     => \&_onprot_mpd_connect_error,
            'mpd_connect_error_retriable' => \&_onprot_mpd_connect_error,
            'mpd_connected'               => \&_onprot_mpd_connected,
            'mpd_disconnected'            => \&_onprot_mpd_disconnected,
            'mpd_data'       =>  \&_onprot_mpd_data,
            'mpd_error'      =>  \&_onprot_mpd_error,
            # public events
            'disconnect'     => \&_onpub_disconnect,
            '_default'       => \&POE::Component::Client::MPD::_onpub_default,
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
            my $meth = "_do_$1";
            $h->{playlist}->$meth($k, $h, $msg);
        }

        # collection commands
        when (/^coll\.(.*)$/) {
            my $meth = "_do_$1";
            $h->{collection}->$meth($k, $h, $msg);
        }

        # basic commands
        default {
            my $meth = "_do_$event";
            $h->{commands}->$meth($k, $h, $msg);
        }
    }
}


#--
# EVENTS HANDLERS
#

# -- public events.

#
# catch-all handler for pococm events that drive mpd.
#
sub _onpub_default {
    my ($k, $h, $event, $params) = @_[KERNEL, HEAP, ARG0, ARG1];

    # check if event is handled.
    my @events_commands = qw{
        version kill updatedb urlhandlers
        volume output_enable output_disable
        stats status current song songid
        repeat fade random
        play playid pause stop next prev seek seekid
    };
    my @events_playlist = qw{
        pl.as_items pl.items_changed_since
        pl.add pl.delete pl.deleteid pl.clear pl.crop
        pl.shuffle pl.swap pl.swapid pl.move pl.moveid
        pl.load pl.save pl.rm
    };
    my @events_collection = qw{
        coll.all_items coll.all_items_simple coll.items_in_dir
        coll.all_albums coll.all_artists coll.all_titles coll.all_files
        coll.song coll.songs_with_filename_partial
        coll.albums_by_artist coll.songs_by_artist coll.songs_by_artist_partial
            coll.songs_from_album coll.songs_from_album_partial
            coll.songs_with_title coll.songs_with_title_partial
    };
    my @ok_events = ( @events_commands, @events_playlist, @events_collection );
    return unless $event ~~ [ @ok_events ];

    # create the message that will hold
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from       => $_[SENDER]->ID,
        request    => $event,  # /!\ $_[STATE] eq 'default'
        params     => $params,
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
# event: mpd_connect_error_retriable( $reason )
# event: mpd_connect_error_fatal( $reason )
#
# Called when pococm-conn could not connect to a mpd server. It can be
# either retriable, or fatal. In bth case, we just need to forward the
# error to our peer session.
#
sub _onprot_mpd_connect_error {
    my ($k, $h, $reason) = @_[KERNEL, HEAP, ARG0];

    my $peer = $h->{status_msgs_to};
    return unless defined $peer;
    $k->post($peer, 'mpd_connect_error_fatal', $reason);
}


#
# event: mpd_connected( $version )
#
# Called when pococm-conn made sure we're talking to a mpd server.
#
sub _onprot_mpd_connected {
    my ($k, $h, $version) = @_[KERNEL, HEAP, ARG0];
    $h->{version} = $version;

    my $peer = $h->{status_msgs_to};
    return unless defined $peer;
    $k->post($peer, 'mpd_connected');
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
    my $peer = $h->{status_msgs_to};
    return unless defined $peer;
    $k->post($peer, 'mpd_disconnected');
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

    # send result.
    $k->post($msg->_from, 'mpd_result', $msg, $msg->_data);
}


#
# Event: mpd_error( $msg, $errstr )
#
# Received when mpd didn't understood a command.
#
sub _onprot_mpd_error {
    my ($k, $msg, $errstr) = @_[KERNEL, ARG0, ARG1];

    $msg->status(0); # failure
    $k->post( $msg->_from, 'mpd_error', $msg, $errstr );
}



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

    # store args for ourself.
    $h->{status_msgs_to} = $args->{status_msgs_to};
    $h->{socket}         = POE::Component::Client::MPD::Connection->spawn(\%params);

    # create objects to treat dispatched events.
    $h->{mpd}        = POE::Component::Client::MPD->new;
    $h->{commands}   = POE::Component::Client::MPD::Commands->new;
    $h->{playlist}   = POE::Component::Client::MPD::Playlist->new;
    $h->{collection} = POE::Component::Client::MPD::Collection->new;
}



=begin FIXME

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

=end FIXME

=cut


1;

__END__


=head1 NAME

POE::Component::Client::MPD - a full-blown mpd client library



=head1 SYNOPSIS

    use POE qw{ Component::Client::MPD };
    POE::Component::Client::MPD->spawn( {
        host           => 'localhost',
        port           => 6600,
        password       => 's3kr3t',  # mpd password
        alias          => 'mpd',     # poe alias
        status_msgs_to => 'myapp',   # session to send status info to
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


=head2 my $id = POCOCM->spawn( \%params )

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


=item * status_msgs_to

A session (name or id) to whom to send connection status to. Optional,
although recommended. No default. When this is done, pococm will send
*additional* events to the session, such as: C<mpd_connected> when
pococm is connected, C<mpd_disconnected> when pococm is disconnected,
etc. You thus need to register some handlers for those events.


=back



=head1 PUBLIC EVENTS ACCEPTED

POCOCM accepts two types of events: some are used to drive the mpd
server, others will change the pococm status.


=head2 MPD-related events

The goal of a POCOCM session is to drive a remote MPD server. This can
be achieved by a lot of events. Due to their sheer number, they have
been regrouped logically in modules.

However, note that to use those events, you need to send them to the
POCOCM session that you created with C<spawn()> (see above). Indeed, the
logical split is only internal: you are to use the same peer.


For a list of public events that update and/or query MPD, see embedded
pod in:

=over 4

=item *

L<POE::Component::Client::MPD::Commands> for general commands


=item *

L<POE::Component::Client::MPD::Playlist> for playlist-related commands.
Those events begin with C<pl.>.


=item *

L<POE::Component::Client::MPD::Collection> for collection-related
commands. Those events begin with C<coll.>.


=back



=head2 POCOCM-related events

Those events allow to drive the POCOCM session.


=over 4

=item * disconnect()

Request the POCOCM to be shutdown. Leave mpd running. Generally sent
when one wants to exit her program.


=back



=head1 PUBLIC EVENTS FIRED

A POCOCM session will fire events, either to answer an incoming event,
or to inform about some changes regarding the remote MPD server.


=head2 Answer events

For each incoming event received by the POCOCM session, it will fire
back one of the following answers:


=over 4

=item * mpd_result( $msg, $answer )

Indicates a success. C<$msg> is a
L<POE::Component::Client::MPD::Message> object with the original
request, to identify the issued command (see
L<POE::Component::Client::MPD::Message> pod for more information). Its
C<status()> attribute is true, further confirming success.


C<$answer> is what has been answered by the MPD server. Depending on the
command, it can be either:

=over 4

=item * C<undef>: commands C<play>, etc.

=item * an L<Audio::MPD::Common::Stats> object: command C<stats>

=item * an L<Audio::MPD::Common::Status> object: command C<status>

=item * an L<Audio::MPD::Common::Item> object: commands C<song>, etc.

=item * an array reference: commands C<coll.files>, etc.

=item * etc.

=back

Refer to the documentation of each event to know what type of answer you
can expect.


=item * mpd_error( $msg, $errstr )

Indicates a failure. C<$msg> is a
L<POE::Component::Client::MPD::Message> object with the original
request, to identify the issued command (see
L<POE::Component::Client::MPD::Message> pod for more information). Its
C<status()> attribute is false, further confirming failure.


C<$errstr> is what the error message as returned been answered by the
MPD server.


=back



=head2 Auto-generated events

The following events are fired by pococm:

=over 4

=item * mpd_connect_error_fatal( $reason )

Called when pococm-conn could not connect to a mpd server. It can be
either retriable, or fatal. Check C<$reason> for more information.


=item * mpd_connected()

Called when pococm-conn made sure we're talking to a mpd server.

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

L<POE::Component::Client::MPD> development takes place on C<< <audio-mpd
at googlegroups.com> >>: feel free to join us. (use
L<http://groups.google.com/group/audio-mpd> to sign in). Our git
repository is located at
L<git://repo.or.cz/poe-component-client-mpd.git>, and can be browsed at
L<http://repo.or.cz/w/poe-component-client-mpd.git>.


You can also look for information on this module at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-Client-MPD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-Client-MPD>

=item * Open bugs

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-Client-MPD>

=back



=head1 AUTHOR

Jerome Quelin, C<< <jquelin@cpan.org> >>



=head1 COPYRIGHT & LICENSE

Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
