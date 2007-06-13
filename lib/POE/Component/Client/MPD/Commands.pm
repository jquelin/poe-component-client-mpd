#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Commands;

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD qw[ :all ];
use POE::Component::Client::MPD::Message;
use Readonly;

use base qw[ Class::Accessor::Fast ];

Readonly my @EVENTS => qw[
    updatedb
    volume output_enable output_disable
    stats status current song songid
    repeat random fade
    play pause stop
];

sub _spawn {
    my $object = __PACKAGE__->new;
    my $session = POE::Session->create(
        inline_states => {
            '_start'      => sub { warn "started: $MPD (" . $_[SESSION]->ID . ")\n"; $_[KERNEL]->alias_set( $MPD ) },
            '_stop'       => sub { warn "stopped: $MPD\n";  },
            '_default'    => \&POE::Component::Client::MPD::_onpub_default,
            '_dispatch'   => \&_onpriv_dispatch,
            'disconnect'  => \&_onpub_disconnect,
        },
        object_states => [ $object => [ map { "_onpub_$_" } @EVENTS ] ]
    );

    return $session->ID;
}

sub _onpriv_dispatch {
    my $msg = $_[ARG0];
    my $event = $msg->_dispatch;
    $event =~ s/^[^.]\.//;
#     warn "dispatching $event\n";
    $_[KERNEL]->yield( "_onpub_$event", $msg );
}


# -- MPD interaction: general commands

#
# event: version()
#
# Fires back an event with the version number.
#
sub _onpub_version {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        data      => $_[HEAP]->{version}
    } );
    $_[KERNEL]->yield( '_mpd_data', $msg );
}


#
# event: kill()
#
# Kill the mpd server, and request the pococm to be shutdown.
#
sub _onpub_kill {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ 'kill' ],
        _cooking  => $RAW,
        _post     => 'disconnect',  # shut down pococm behind us.
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: updatedb( [$path] )
#
# Force mpd to rescan its collection. If $path (relative to MPD's music
# directory) is supplied, MPD will only scan it - otherwise, MPD will rescan
# its whole collection.
#
sub _onpub_updatedb {
    my $msg  = $_[ARG0];
    my $path = defined $msg->_params->[0] ? $msg->_params->[0] : '';

    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ qq[update "$path"] ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: urlhandlers()
#
# Return an array of supported URL schemes.
#
sub _onpub_urlhandlers {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ 'urlhandlers' ],
        _cooking  => $STRIP_FIRST,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- MPD interaction: handling volume & output

#
# event: volume( $volume )
#
# Sets the audio output volume percentage to absolute $volume.
# If $volume is prefixed by '+' or '-' then the volume is changed relatively
# by that value.
#
sub _onpub_volume {
    my ($k, $msg) = @_[KERNEL, ARG0];
    my $volume;

    if ( $msg->_params->[0] =~ /^(-|\+)(\d+)/ ) {
        my ($op, $delta) = ($1, $2);
        if ( not defined $msg->data ) {
            # no status yet - fire an event
            $msg->_dispatch  ( 'status' );
            $msg->_post_to   ( $MPD );
            $msg->_post_event( 'volume' );
            $k->yield( '_dispatch', $msg );
            return;
        }

        # already got a status result
        my $curvol = $msg->data->volume;
        $volume = $op eq '+' ? $curvol + $delta : $curvol - $delta;
    } else {
        $volume = $msg->_params->[0];
    }

    $msg->_cooking  ( $RAW );
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ "setvol $volume" ] );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: output_enable( $output )
#
# Enable the specified audio output. $output is the ID of the audio output.
#
sub _onpub_output_enable {
    my $msg    = $_[ARG0];
    my $output = $msg->_params->[0];

    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ "enableoutput $output" ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: output_disable( $output )
#
# Disable the specified audio output. $output is the ID of the audio output.
#
sub _onpub_output_disable {
    my $msg    = $_[ARG0];
    my $output = $msg->_params->[0];

    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ "disableoutput $output" ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


# -- MPD interaction: retrieving info from current state

#
# event: stats()
#
# Return a hash with the current statistics of MPD.
#
sub _onpub_stats {
    my $msg = $_[ARG0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ 'stats' ] );
    $msg->_cooking  ( $AS_KV );
    $msg->_transform( $AS_STATS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: status()
#
# Return a hash with the current status of MPD.
#
sub _onpub_status {
    my $msg = $_[ARG0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ 'status' ] );
    $msg->_cooking  ( $AS_KV );
    $msg->_transform( $AS_STATUS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: current()
#
# Return a POCOCM::Item::Song representing the song currently playing.
#
sub _onpub_current {
    my $msg = $_[ARG0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: song( [$song] )
#
# Return a POCOCM::Item::Song representing the song number $song.
# If $song is not supplied, returns the current song.
#
sub _onpub_song {
    my $msg  = $_[ARG0];
    my $song = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ defined $song ? "playlistinfo $song" : 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: songid( [$songid] )
#
# Return a POCOCM::Item::Song representing the song id $songid.
# If $songid is not supplied, returns the current song.
#
sub _onpub_songid {
    my $msg  = $_[ARG0];
    my $song = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ defined $song ? "playlistid $song" : 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


# -- MPD interaction: altering settings

#
# event: repeat( [$repeat] )
#
# Set the repeat mode to $repeat (1 or 0). If $repeat is not specified then
# the repeat mode is toggled.
#
sub _onpub_repeat {
    my ($k, $msg) = @_[KERNEL, ARG0];

    my $mode = $msg->_params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->data ) {
            # no status yet - fire an event
            $msg->_dispatch  ( 'status' );
            $msg->_post_to   ( $MPD );
            $msg->_post_event( 'repeat' );
            $k->post( $MPD, '_dispatch', $msg );
            return;
        }

        $mode = $msg->data->repeat ? 0 : 1; # negate current value
    }

    $msg->_cooking ( $RAW );
    $msg->_answer  ( $DISCARD );
    $msg->_commands( [ "repeat $mode" ] );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: fade( [$seconds] )
#
# Enable crossfading and set the duration of crossfade between songs. If
# $seconds is not specified or $seconds is 0, then crossfading is disabled.
#
sub _onpub_fade {
    my $msg     = $_[ARG0];
    my $seconds = $msg->_params->[0] || 0;
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ "crossfade $seconds" ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: random( [$random] )
#
# Set the random mode to $random (1 or 0). If $random is not specified then
# the random mode is toggled.
#
sub _onpub_random {
    my ($k, $msg) = @_[KERNEL, ARG0];

    my $mode = $msg->_params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->data ) {
            # no status yet - fire an event
            $msg->_dispatch  ( 'status' );
            $msg->_post_to   ( $MPD );
            $msg->_post_event( 'random' );
            $k->post( $MPD, '_dispatch', $msg );
            return;
        }

        $mode = $msg->data->random ? 0 : 1; # negate current value
    }

    $msg->_cooking ( $RAW );
    $msg->_answer  ( $DISCARD );
    $msg->_commands( [ "random $mode" ] );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}



# -- MPD interaction: controlling playback

#
# event: play( [$song] )
#
# Begin playing playlist at song number $song. If no argument supplied,
# resume playing.
#
sub _onpub_play {
    my $msg = $_[ARG0];
    my $number = defined $msg->_params->[0] ? $msg->_params->[0] : '';
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ "play $number" ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: playid( [$song] )
#
# Begin playing playlist at song ID $song. If no argument supplied,
# resume playing.
#
sub _onpub_playid {
    my $number = defined $_[ARG0] ? $_[ARG0] : '';
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "playid $number" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pause( [$sate] )
#
# Pause playback. If $state is 0 then the current track is unpaused, if
# $state is 1 then the current track is paused.
#
# Note that if $state is not given, pause state will be toggled.
#
sub _onpub_pause {
    my $msg = $_[ARG0];
    my $state = defined $msg->_params->[0] ? $msg->_params->[0] : '';
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ "pause $state" ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: stop()
#
# Stop playback
#
sub _onpub_stop {
    my $msg = $_[ARG0];
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ 'stop' ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: next()
#
# Play next song in playlist.
#
sub _onpub_next {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ 'next' ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: prev()
#
# Play previous song in playlist.
#
sub _onpub_prev {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ 'previous' ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: seek( $time, [$song] )
#
# Seek to $time seconds in song number $song. If $song number is not specified
# then the perl module will try and seek to $time in the current song.
#
sub _onpub_seek {
    my ($time, $song) = @_[ARG0, ARG1];
    $time ||= 0; $time = int $time;
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _cooking  => $RAW,
    } );

    if ( defined $song ) {
        $msg->_commands( [ "seek $song $time" ] );
    } else {
        $msg->_pre_from( '_seek_need_current' );
        $msg->_pre_event( 'status' );
        $msg->_pre_data( $time );
    }
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _seek_need_current( $msg, $current )
#
# Use $current to get current song, before sending real seek $msg.
#
sub _onpriv_seek_need_current {
    my ($msg, $current) = @_[ARG0, ARG1];
    my $song = $current->data->song;
    my $time = $msg->_pre_data;
    $msg->_commands( [ "seek $song $time" ] );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: seekid( $time, [$songid] )
#
# Seek to $time seconds in song ID $songid. If $songid number is not specified
# then the perl module will try and seek to $time in the current song.
#
sub _onpub_seekid {
    my ($time, $song) = @_[ARG0, ARG1];
    $time ||= 0; $time = int $time;
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _cooking  => $RAW,
    } );

    if ( defined $song ) {
        $msg->_commands( [ "seekid $song $time" ] );
    } else {
        $msg->_pre_from( '_seekid_need_current' );
        $msg->_pre_event( 'status' );
        $msg->_pre_data( $time );
    }
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _seekid_need_current( $msg, $current )
#
# Use $current to get current song, before sending real seekid $msg.
#
sub _onpriv_seekid_need_current {
    my ($msg, $current) = @_[ARG0, ARG1];
    my $song = $current->data->song;
    my $time = $msg->_pre_data;
    $msg->_commands( [ "seekid $song $time" ] );
    $_[KERNEL]->yield( '_send', $msg );
}


1;

__END__

=head1 NAME

POE::Component::Client::MPD::Commands - module handling basic commands


=head1 DESCRIPTION

C<POCOCM::Commands> is responsible for handling general purpose commands.
To achieve those commands, send the corresponding event to the POCOCM
session you created: it will be responsible for dispatching the event
where it is needed.


=head1 PUBLIC EVENTS

The following is a list of general purpose events accepted by POCOCM.


=head2 General commands

=head2 Handling volume & output

=head2 Retrieving info from current state

=head2 Altering settings

=head2 Controlling playback


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
