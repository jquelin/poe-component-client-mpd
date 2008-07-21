#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Connection;

use strict;
use warnings;

use Audio::MPD::Common::Item;
use POE;
use POE::Component::Client::MPD::Message;
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
#   - host: hostname of the mpd server.
#   - port: port of the mpd server.
#   - id:   poe session id of the peer to dialog with
#
# Those args are not supposed to be empty - ie, there's no defaut, and you
# will get an error if you don't follow this requirement! Yes, this is a
# private class, and you're not supposed to use it beyond pococm. :-)
#
sub spawn {
    my ($type, $args) = @_;

    # connect to mpd server.
    my $id = POE::Component::Client::TCP->new(
        RemoteAddress => $args->{host},
        RemotePort    => $args->{port},
        Filter        => 'POE::Filter::Line',
        Args          => [ $args->{id} ],


        ServerError  => sub { }, # quiet errors
        Started      => \&_onpriv_Started,
        Connected    => \&_onpriv_Connected,
        ConnectError => \&_onpriv_ConnectError,
        Disconnected => \&_onpriv_Disconnected,
        ServerInput  => \&_onpriv_ServerInput,

        InlineStates => {
            # protected events
            _send       => \&_onprot_send,         # send data
            _disconnect => \&_onprot_disconnect,   # force quit

            # private events
            _ServerInput_data         => \&_onpriv_ServerInput_data,
            _ServerInput_data_eot     => \&_onpriv_ServerInput_data_eot,
            _ServerInput_error        => \&_onpriv_ServerInput_error,
        }
    );

    return $id;
}


#
# -- SUBS
#

#--
# private subs

sub _parse_first_input_line {
    my ($k, $h, $input) = @_;

    if ( $input =~ /^OK MPD (.*)$/ ) {
        $h->{is_mpd} = 1;  # remote server *is* a mpd sever
        $k->post($h->{session}, '_conn_connected', $1);
    } else {
        # oops, it appears that it's not a mpd server...
        $k->post(
            $h->{session}, '_conn_connect_error_fatal',
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
    my $h = $_[HEAP];
    $h->{session}       = $_[ARG0];     # poe-session peer
    $h->{on_disconnect} = $RECONNECT;   # disconnect policy
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
    $k->post(
        $h->{session}, '_conn_connect_error_retriable',
        "$syscall: ($errno) $errstr"
    );
    $k->delay_add('reconnect' => 5); # auto-reconnect in 5 seconds
}


#
# event: Disconnected()
#
# Called whenever the tcp connection is broken / finished.
#
sub _onpriv_Disconnected {
    my ($k, $h) = @_[KERNEL, HEAP];
    return if $h->{on_disconnect} != $RECONNECT;
    $k->post( $h{session}, '_conn_disconnected');
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
        _parse_first_input_line($k, $h, $input);
        return;
    }


    # table of dispatch: check input against regex, and fire event
    # if it did match.
    my @dispatch = (
        [ qr/^OK$/,        '_ServerInput_data_eot' ],
        [ qr/^ACK (.*)/,   '_ServerInput_error'    ],
        [ qr/^/,           '_ServerInput_data'     ],
    );

    foreach my $d (@dispatch) {
        next unless $input =~ $d->[0];
        $_[KERNEL]->yield( $d->[1], $input, $1 );
        last;
    }
}


#
# event: _ServerInput_data( $input )
#
# Called when the stream of data is finished.
#
sub _onpriv_ServerInput_data {
    my ($h, $input) = @_[HEAP, ARG0];

    # regular data, to be cooked (if needed) and stored.
    my $msg = $h->{fifo}[0];
    my $cooking = $msg->_cooking;
    COOKING:
    {
        $cooking == $RAW and do {
            # nothing to do, just push the data.
            push @{ $h->{incoming} }, $input;
            last COOKING;
        };

        $cooking == $AS_ITEMS and do {
            # Lots of POCOCM methods are sending commands and then parse the
            # output to build an amc-item.
            my ($k,$v) = split /:\s+/, $input, 2;
            $k = lc $k;

            if ( $k eq 'file' || $k eq 'directory' || $k eq 'playlist' ) {
                # build a new amc-item
                my $item = Audio::MPD::Common::Item->new( $k => $v );
                push @{ $h->{incoming} }, $item;
                last COOKING;
            }

            # just complete the current amc-item
            $h->{incoming}[-1]->$k($v);
            last COOKING;
        };

        $cooking == $AS_KV and do {
            # Lots of POCOCM methods are sending commands and then parse the
            # output to get a list of key / value (with the colon ":" acting
            # as separator).
            my @data = split(/:\s+/, $input, 2);
            push @{ $h->{incoming} }, @data;
            last COOKING;
        };

        $cooking == $STRIP_FIRST and do {
            # Lots of POCOCM methods are sending commands and then parse the
            # output to remove the first field (with the colon ":" acting as
            # separator).
            $input = ( split(/:\s+/, $input, 2) )[1];
            push @{ $h->{incoming} }, $input;
            last COOKING;
        };
    }

}


#
# event: _ServerInput_data_eot()
#
# Called when the stream of data is finished.
#
sub _onpriv_ServerInput_data_eot {
    my ($k, $h) = @_[KERNEL, HEAP];
    my $session = $h->{session};
    my $msg     = shift @{ $h->{fifo} };    # remove completed msg
    $msg->data( $h->{incoming} );           # complete message with data
    $k->post($session, '_mpd_data', $msg);  # signal poe session
    $h->{incoming} = [];                    # reset incoming data
}


#
# event: _ServerInput_error(undef, $error)
#
# Called when a message resulted in an $error for mpd.
#
sub _onpriv_ServerInput_error {
    my $h = $_[HEAP];
    my $session = $h->{session};
    my $msg     = shift @{ $h->{fifo} };
    $msg->error( $_[ARG1] );
    $_[KERNEL]->post($session, '_mpd_error', $msg);
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

The hostname of the mpd server.


=item * port

The port of the mpd server.


=item * id

The POE session id of the peer to dialog with.


=back


Those args are not supposed to be empty - ie, there's no defaut, and you
will get an error if you don't follow this requirement! Yes, this is a
private class, and you're not supposed to use it beyond pococm. :-)




=head1 PUBLIC EVENTS ACCEPTED

The following events are accepted from outside this class - but of course
restricted to POCOCM (in oo-lingo, they are more protected rather than
public).



=head2 disconnect()

Request the pococm-connection to be shutdown. No argument.


=head2 send( $request )

Request pococm-conn to send the C<$request> over the wires. Note that this
request is a pococm-request object, and that the ->_commands should
B<not> be newline terminated.




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
