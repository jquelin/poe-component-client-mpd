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

Readonly my @EVENTS => qw[ ];

sub _spawn {
    my $session = POE::Session->create(
        inline_states => {
            '_start'      => sub { warn "started: $MPD\n"; $_[KERNEL]->alias_set( $MPD ) },
            '_stop'       => sub { warn "stopped: $MPD\n";  },
            '_default'    => \&POE::Component::Client::MPD::_onpub_default,
            '_dispatch'   => \&_onpriv_dispatch,
            'disconnect'  => \&_onpub_disconnect,
            map { $_ => \&{"_onpub_$_"} } @EVENTS,
        },
    );

    return $session->ID;
}

sub _onpriv_dispatch {
    my $msg = $_[ARG0];
    my $event = $msg->_dispatch;
    $event =~ s/^[^.]\.//;
    warn "dispatching $event\n";
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
    my $path = defined $_[ARG0] ? $_[ARG0] : '';
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "update $path" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
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
    # create stub message.
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _cooking  => $RAW,
    } );

    my $volume = $_[ARG0];
    if ( $volume =~ /^(-|\+)(\d+)/ )  {
        $msg->_pre_from( '_volume_status' );
        $msg->_pre_event( 'status' );
        $msg->_pre_data( $volume );
    } else {
        $msg->_commands( [ "setvol $volume" ] );
    }

    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _volume_status( $msg, $status )
#
# Use $status to get current volume, before sending real volume $msg.
#
sub _onpriv_volume_status {
    my ($msg, $status) = @_[ARG0, ARG1];
    my $curvol = $status->data->volume;
    my $volume = $msg->_pre_data;
    $volume =~ /^(-|\+)(\d+)/;
    $volume = $1 eq '+' ? $curvol + $2 : $curvol - $2;
    $msg->_commands( [ "setvol $volume" ] );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: output_enable( $output )
#
# Enable the specified audio output. $output is the ID of the audio output.
#
sub _onpub_output_enable {
    my $output = $_[ARG0];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "enableoutput $output" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: output_disable( $output )
#
# Disable the specified audio output. $output is the ID of the audio output.
#
sub _onpub_output_disable {
    my $output = $_[ARG0];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "disableoutput $output" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- MPD interaction: retrieving info from current state

#
# event: stats()
#
# Return a hash with the current statistics of MPD.
#
sub _onpub_stats {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from      => $_[SENDER]->ID,
        _request   => $_[STATE],
        _answer    => $SEND,
        _commands  => [ 'stats' ],
        _cooking   => $AS_KV,
        _transform => $AS_STATS,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: status()
#
# Return a hash with the current status of MPD.
#
sub _onpub_status {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from      => $_[SENDER]->ID,
        _request   => $_[STATE],
        _answer    => $SEND,
        _commands  => [ 'status' ],
        _cooking   => $AS_KV,
        _transform => $AS_STATUS,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: current()
#
# Return a POCOCM::Item::Song representing the song currently playing.
#
sub _onpub_current {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from      => $_[SENDER]->ID,
        _request   => $_[STATE],
        _answer    => $SEND,
        _commands  => [ 'currentsong' ],
        _cooking   => $AS_ITEMS,
        _transform => $AS_SCALAR,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: song( [$song] )
#
# Return a POCOCM::Item::Song representing the song number $song.
# If $song is not supplied, returns the current song.
#
sub _onpub_song {
    my ($k,$song) = @_[KERNEL, ARG0];

    my $msg = POE::Component::Client::MPD::Message->new( {
        _from      => $_[SENDER]->ID,
        _request   => $_[STATE],
        _answer    => $SEND,
        _commands  => [ defined $song ? "playlistinfo $song" : 'currentsong' ],
        _cooking   => $AS_ITEMS,
        _transform => $AS_SCALAR,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: songid( [$songid] )
#
# Return a POCOCM::Item::Song representing the song id $songid.
# If $songid is not supplied, returns the current song.
#
sub _onpub_songid {
    my ($k,$song) = @_[KERNEL, ARG0];

    my $msg = POE::Component::Client::MPD::Message->new( {
        _from      => $_[SENDER]->ID,
        _request   => $_[STATE],
        _answer    => $SEND,
        _commands  => [ defined $song ? "playlistid $song" : 'currentsong' ],
        _cooking   => $AS_ITEMS,
        _transform => $AS_SCALAR,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- MPD interaction: altering settings

#
# event: repeat( [$repeat] )
#
# Set the repeat mode to $repeat (1 or 0). If $repeat is not specified then
# the repeat mode is toggled.
#
sub _onpub_repeat {
    # create stub message.
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _cooking  => $RAW,
    } );

    my $mode = $_[ARG0];
    if ( not defined $mode )  {
        $msg->_pre_from( '_repeat_status' );
        $msg->_pre_event( 'status' );
    } else {
        $mode = $mode ? 1 : 0;   # force integer
        $msg->_commands( [ "repeat $mode" ] );
    }

    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _repeat_status( $msg, $status )
#
# Use $status to get current repeat mode, before sending real repeat $msg.
#
sub _onpriv_repeat_status {
    my ($msg, $status) = @_[ARG0, ARG1];
    my $mode = not $status->data->repeat;
    $mode = $mode ? 1 : 0;   # force integer
    $msg->_commands( [ "repeat $mode" ] );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: fade( [$seconds] )
#
# Enable crossfading and set the duration of crossfade between songs. If
# $seconds is not specified or $seconds is 0, then crossfading is disabled.
#
sub _onpub_fade {
    my $seconds = $_[ARG0];
    $seconds ||= 0;
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "crossfade $seconds" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: random( [$random] )
#
# Set the random mode to $random (1 or 0). If $random is not specified then
# the random mode is toggled.
#
sub _onpub_random {
    # create stub message.
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _cooking  => $RAW,
    } );

    my $mode = $_[ARG0];
    if ( not defined $mode )  {
        $msg->_pre_from( '_random_status' );
        $msg->_pre_event( 'status' );
    } else {
        $mode = $mode ? 1 : 0;   # force integer
        $msg->_commands( [ "random $mode" ] );
    }

    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _repeat_status( $msg, $status )
#
# Use $status to get current repeat mode, before sending real repeat $msg.
#
sub _onpriv_random_status {
    my ($msg, $status) = @_[ARG0, ARG1];
    my $mode = not $status->data->random;
    $mode = $mode ? 1 : 0;   # force integer
    $msg->_commands( [ "random $mode" ] );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- MPD interaction: controlling playback

#
# event: play( [$song] )
#
# Begin playing playlist at song number $song. If no argument supplied,
# resume playing.
#
sub _onpub_play {
    my $number = defined $_[ARG0] ? $_[ARG0] : '';
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "play $number" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
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
    my $state = defined $_[ARG0] ? $_[ARG0] : '';
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "pause $state" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: stop()
#
# Stop playback
#
sub _onpub_stop {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ 'stop' ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
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
