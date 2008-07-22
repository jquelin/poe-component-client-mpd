#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Connection;

use 5.010;
use strict;
use warnings;

use Audio::MPD::Common::Item;
use POE;
use POE::Component::Client::MPD::Message; # for exported constants
use POE::Component::Client::TCP;
use Readonly;


Readonly my $IGNORE    => 0;
Readonly my $RECONNECT => 1;

#
# -- METHODS
#

#--
# public methods

#
# my $id = POE::Component::Client::MPD::Connection->spawn(\%params);
#
# This method will create a POE::Component::TCP session responsible for
# low-level communication with mpd. It will return the poe id of the
# session newly created.
#
# Arguments are passed as a hash reference, with the keys:
#   - host:  hostname of the mpd server.
#   - port:  port of the mpd server.
#   - id:    poe session id of the peer to dialog with
#   - retyr: time to wait before attempting to reconnect. defaults to 5.
#
# The args without default are not supposed to be empty - ie, you will
# get an error if you don't follow this requirement! Yes, this is a
# private class, and you're not supposed to use it beyond pococm. :-)
#
sub spawn {
    my ($type, $args) = @_;

    # connect to mpd server.
    my $id = POE::Component::Client::TCP->new(
        RemoteAddress => $args->{host},
        RemotePort    => $args->{port},
        Filter        => 'POE::Filter::Line',
        Args          => [ $args ],


        ServerError  => sub { }, # quiet errors
        Started      => \&_onpriv_Started,
        Connected    => \&_onpriv_Connected,
        ConnectError => \&_onpriv_ConnectError,
        Disconnected => \&_onpriv_Disconnected,
        ServerInput  => \&_onpriv_ServerInput,

        InlineStates => {
            # protected events
            send       => \&_onprot_send,         # send data
            disconnect => \&_onprot_disconnect,   # force quit
        }
    );

    return $id;
}


#
# -- SUBS
#

#--
# private subs


#
# _got_data($kernel, $heap, $input);
#
# called when receiving another piece of data.
#
sub _got_data {
    my ($k, $h, $input) = @_;

    # regular data, to be cooked (if needed) and stored.
    my $msg = $h->{fifo}[0];

    given ($msg->_cooking) {
        when ($RAW) {
            # nothing to do, just push the data.
            push @{ $h->{incoming} }, $input;
        }

        when ($AS_ITEMS) {
            # Lots of POCOCM methods are sending commands and then parse the
            # output to build an amc-item.
            my ($k,$v) = split /:\s+/, $input, 2;
            $k = lc $k;

            if ( $k eq 'file' || $k eq 'directory' || $k eq 'playlist' ) {
                # build a new amc-item
                my $item = Audio::MPD::Common::Item->new( $k => $v );
                push @{ $h->{incoming} }, $item;
            }

            # just complete the current amc-item
            $h->{incoming}[-1]->$k($v);
        }

        when ($AS_KV) {
            # Lots of POCOCM methods are sending commands and then parse the
            # output to get a list of key / value (with the colon ":" acting
            # as separator).
            my @data = split(/:\s+/, $input, 2);
            push @{ $h->{incoming} }, @data;
        }

        when ($STRIP_FIRST) {
            # Lots of POCOCM methods are sending commands and then parse the
            # output to remove the first field (with the colon ":" acting as
            # separator).
            $input = ( split(/:\s+/, $input, 2) )[1];
            push @{ $h->{incoming} }, $input;
        }
    }
}


#
# _got_data_eot($kernel, $heap)
#
# called when the stream of data is finished. used to send the received
# data.
#
sub _got_data_eot {
    my ($k, $h) = @_;
    my $session = $h->{session};
    my $msg     = shift @{ $h->{fifo} };     # remove completed msg
    $msg->_data($h->{incoming});             # complete message with data
    $k->post($session, 'mpd_data', $msg);    # signal poe session
    $h->{incoming} = [];                     # reset incoming data
}


#
# _got_error($kernel, $heap, $errstr);
#
# called when the mpd server reports an error. used to report the error
# to the pococm.
#
sub _got_error {
    my ($k, $h, $errstr) = @_;

    my $session = $h->{session};
    my $msg     = shift @{ $h->{fifo} };
    $k->post($session, 'mpd_error', $msg, $errstr);
}


#
# _got_first_input_line($kernel, $heap, $input);
#
# called when the mpd server fires the first line. used to check whether
# we are talking to a regular mpd server.
#
sub _got_first_input_line {
    my ($k, $h, $input) = @_;

    if ( $input =~ /^OK MPD (.*)$/ ) {
        $h->{is_mpd} = 1;  # remote server *is* a mpd sever
        $k->post($h->{session}, 'mpd_connected', $1);
    } else {
        # oops, it appears that it's not a mpd server...
        $k->post(
            $h->{session}, 'mpd_connect_error_fatal',
            "Not a mpd server - welcome string was: '$input'",
        );
    }
}



#
# -- EVENTS HANDLERS
#

#--
# protected events

#
# event: disconnect()
#
# Request the pococm-connection to be shutdown. No argument.
#
sub _onprot_disconnect {
    $_[HEAP]->{on_disconnect} = $IGNORE; # no more auto-reconnect.
    $_[KERNEL]->yield( 'shutdown' );     # shutdown socket.
}


#
# event: send($message)
#
# Request pococm-conn to send the commands of $message over the wires.
# Note that $message is a pococm-message object, and that the ->_commands
# should *not* be newline terminated.
#
sub _onprot_send {
    my ($h, $msg) = @_[HEAP, ARG0];
    # $_[HEAP]->{server} is a reserved slot of pococ-tcp.
    $h->{server}->put( @{ $msg->_commands } );
    push @{ $h->{fifo} }, $msg;
}


#--
# private events

#
# event: Started($id)
#
# Called whenever the session is started, but before the tcp connection is
# established. Receives the session $id of the poe-session that will be our
# peer during the life of this session.
#
sub _onpriv_Started {
    my ($h, $args) = @_[HEAP, ARG0];
    $h->{session}       = $args->{id};          # poe-session peer
    $h->{retry}         = $args->{retry} // 5;  # sleep time before retry
    $h->{on_disconnect} = $RECONNECT;           # disconnect policy
}


#
# event: Connected()
#
# Called whenever the tcp connection is established.
#
sub _onpriv_Connected {
    my $h = $_[HEAP];
    $h->{fifo}     = [];     # reset current messages
    $h->{incoming} = [];     # reset incoming data
    $h->{is_mpd}   = 0;      # is remote server a mpd sever?
}


#
# event: ConnectError($syscall, $errno, $errstr)
#
# Called whenever the tcp connection fails to be established. Receives
# the $syscall that failed, as well as $errno and $errstr.
#
sub _onpriv_ConnectError {
    my ($k, $h, $syscall, $errno, $errstr) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    return if $h->{on_disconnect} != $RECONNECT;
    $k->post(
        $h->{session}, 'mpd_connect_error_retriable',
        "$syscall: ($errno) $errstr"
    );
    $k->delay_add('reconnect' => $h->{retry}); # auto-reconnect in $retry seconds
}


#
# event: Disconnected()
#
# Called whenever the tcp connection is broken / finished.
#
sub _onpriv_Disconnected {
    my ($k, $h) = @_[KERNEL, HEAP];
    return if $h->{on_disconnect} != $RECONNECT;
    $k->post($h->{session}, 'mpd_disconnected');
    $k->yield('reconnect'); # auto-reconnect
}


#
# event: ServerInput($input)
#
# Called whenever the tcp peer sends data over the wires, with the $input
# transmitted given as param.
#
sub _onpriv_ServerInput {
    my ($k, $h, $input) = @_[KERNEL, HEAP, ARG0];

    # did we check we were talking to a mpd server?
    if ( not $h->{is_mpd} ) {
        _got_first_input_line($k, $h, $input);
        return;
    }

    # table of dispatch: check input against regex, and process it.
    given ($input) {
        when ( /^OK$/ )      { _got_data_eot($k, $h);     }
        when ( /^ACK (.*)/ ) { _got_error($k, $h, $1);    }
        default              { _got_data($k, $h, $input); }
    }
}



1;

__END__

=head1 NAME

POE::Component::Client::MPD::Connection - module handling the tcp connection with mpd




=head1 DESCRIPTION

This module will spawn a poe session responsible for low-level communication
with mpd. It is written as a pococ-tcp, which is taking care of everything
needed.

Note that you're B<not> supposed to use this class directly: it's one of the
helper class for POCOCM.




=head1 PUBLIC METHODS

=head2 spawn( \%params )

This method will create a POE::Component::TCP session responsible for low-level
communication with mpd.

It will return the poe id of the session newly created.

You should provide some arguments as a hash reference, where the hash keys are:

=over 4

=item * host

The hostname of the mpd server. No default.


=item * port

The port of the mpd server. No default.


=item * id

The POE session id of the peer to dialog with. No default.


=item * retry

How much time to wait (in seconds) before attempting socket
reconnection. Defaults to 5.


=back


The args without default are not supposed to be empty - ie, you will get
an error if you don't follow this requirement! Yes, this is a private
class, and you're not supposed to use it beyond pococm. :-)




=head1 PUBLIC EVENTS ACCEPTED

The following events are accepted from outside this class - but of course
restricted to POCOCM (in oo-lingo, they are more protected rather than
public).



=head2 disconnect( )

Request the pococm-connection to be shutdown. No argument.


=head2 send($message)

Request pococm-conn to send the C<$message> over the wires. Note that
this request is a pococm-message object, and that the ->_commands should
B<not> be newline terminated.




=head1 PUBLIC EVENTS FIRED

The following events are fired from the spawned session.

=head2 mpd_connected($version)

Fired when the session is connected to a mpd server. This event isn't
fired when the socket connection takes place, but when the session has
checked that remote peer is a real mpd server. C<$version> is the
advertised mpd server version.


=head2 mpd_connect_error_fatal()

Fired when the session is connected to a server which happens to be
something else than a mpd server. No retries will be done.


=head2 mpd_connect_error_retriable($errstr)

Fired when the session has troubles connecting to the server. C<$errstr>
will point the faulty syscall that failed. Re-connection will be tried
after 5 seconds.


=head2 mpd_data($msg)

Fired when C<$msg> has been sent over the wires, and mpd server has
answered with success.


=head2 mpd_disconnected()

Fired when the socket has been disconnected for whatever reason. Note
that this event is B<not> fired in the case of a programmed shutdown
(see C<disconnect> event above).


=head2 mpd_error($msg,$errstr)

Fired when C<$msg> has been sent over the wires, and mpd server has
answered with an error message C<$errstr>.




=head1 SEE ALSO

For all related information (bug reporting, mailing-list, pointers to
MPD and POE, etc.), refer to C<POE::Component::Client::MPD>'s pod,
section C<SEE ALSO>




=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>




=head1 COPYRIGHT & LICENSE

Copyright (c) 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
