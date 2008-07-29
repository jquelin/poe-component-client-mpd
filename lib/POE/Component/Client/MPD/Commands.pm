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
use POE::Component::Client::MPD;
use POE::Component::Client::MPD::Message;
use Readonly;

use base qw[ Class::Accessor::Fast ];

=pod

Readonly my @EVENTS => qw[
    disconnect
    version kill updatedb urlhandlers
    volume output_enable output_disable
    stats status current song songid
    repeat random fade
    play playid pause stop next prev seek seekid
];

sub _spawn {
    my $object = __PACKAGE__->new;
    my $session = POE::Session->create(
        inline_states => {
            '_start'      => sub { $_[KERNEL]->alias_set( $MPD ) },
            '_default'    => \&POE::Component::Client::MPD::_onpub_default,
            '_dispatch'   => \&_onpriv_dispatch,
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

=cut

# -- MPD interaction: general commands

=pod

sub _onpub_disconnect {
    my $k = $_[KERNEL];
    $k->alias_remove( $MPD );
    $k->post( $_HUB, '_disconnect' );
}

=cut

#
# event: version()
#
# Fires back an event with the version number.
#
sub _do_version {
    my ($self, $k, $h, $msg) = @_;
    $msg->status(1);
    $k->post( $msg->_from, 'mpd_result', $msg, $h->{version} );
}


#
# event: kill()
#
# Kill the mpd server, and request the pococm to be shutdown.
#
sub _do_kill {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'kill' ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
    $k->delay_set('disconnect'=>1);
}


#
# event: updatedb( [$path] )
#
# Force mpd to rescan its collection. If $path (relative to MPD's music
# directory) is supplied, MPD will only scan it - otherwise, MPD will rescan
# its whole collection.
#
sub _do_updatedb {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';

    $msg->_commands( [ qq{update "$path"} ] );
    $msg->_cooking ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: urlhandlers()
#
# Return an array of supported URL schemes.
#
sub _do_urlhandlers {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'urlhandlers' ] );
    $msg->_cooking  ( $STRIP_FIRST );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- MPD interaction: handling volume & output

#
# event: volume( $volume )
#
# Sets the audio output volume percentage to absolute $volume.
# If $volume is prefixed by '+' or '-' then the volume is changed relatively
# by that value.
#
sub _do_volume {
    my ($self, $k, $h, $msg) = @_;

    my $volume;
    if ( $msg->params->[0] =~ /^(-|\+)(\d+)/ ) {
        my ($op, $delta) = ($1, $2);
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'volume' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        # already got a status result
        my $curvol = $msg->_data->volume;
        $volume = $op eq '+' ? $curvol + $delta : $curvol - $delta;
    } else {
        $volume = $msg->params->[0];
    }

    $msg->_commands ( [ "setvol $volume" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: output_enable( $output )
#
# Enable the specified audio output. $output is the ID of the audio output.
#
sub _do_output_enable {
    my ($self, $k, $h, $msg) = @_;
    my $output = $msg->params->[0];

    $msg->_commands ( [ "enableoutput $output" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: output_disable( $output )
#
# Disable the specified audio output. $output is the ID of the audio output.
#
sub _do_output_disable {
    my ($self, $k, $h, $msg) = @_;
    my $output = $msg->params->[0];

    $msg->_commands ( [ "disableoutput $output" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- MPD interaction: retrieving info from current state

#
# event: stats()
#
# Return a hash with the current statistics of MPD.
#
sub _do_stats {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'stats' ] );
    $msg->_cooking  ( $AS_KV );
    $msg->_transform( $AS_STATS );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: status()
#
# Return a hash with the current status of MPD.
#
sub _do_status {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'status' ] );
    $msg->_cooking  ( $AS_KV );
    $msg->_transform( $AS_STATUS );
    $k->post( $h->{socket}, 'send', $msg );
}



#
# event: current()
#
# Return a POCOCM::Item::Song representing the song currently playing.
#
sub _do_current {
    my ($self, $k, $h, $msg) = @_;

    $msg->_commands ( [ 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: song( [$song] )
#
# Return a POCOCM::Item::Song representing the song number $song.
# If $song is not supplied, returns the current song.
#
sub _do_song {
    my ($self, $k, $h, $msg) = @_;
    my $song = $msg->params->[0];

    $msg->_commands ( [ defined $song ? "playlistinfo $song" : 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: songid( [$songid] )
#
# Return a POCOCM::Item::Song representing the song id $songid.
# If $songid is not supplied, returns the current song.
#
sub _do_songid {
    my ($self, $k, $h, $msg) = @_;
    my $song = $msg->params->[0];

    $msg->_commands ( [ defined $song ? "playlistid $song" : 'currentsong' ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- MPD interaction: altering settings

#
# event: repeat( [$repeat] )
#
# Set the repeat mode to $repeat (1 or 0). If $repeat is not specified then
# the repeat mode is toggled.
#
sub _do_repeat {
    my ($self, $k, $h, $msg) = @_;

    my $mode = $msg->params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'repeat' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $mode = $msg->_data->repeat ? 0 : 1; # negate current value
    }

    $msg->_cooking ( $RAW );
    $msg->_commands( [ "repeat $mode" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: fade( [$seconds] )
#
# Enable crossfading and set the duration of crossfade between songs. If
# $seconds is not specified or $seconds is 0, then crossfading is disabled.
#
sub _do_fade {
    my ($self, $k, $h, $msg) = @_;
    my $seconds = $msg->params->[0] // 0;

    $msg->_commands ( [ "crossfade $seconds" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: random( [$random] )
#
# Set the random mode to $random (1 or 0). If $random is not specified then
# the random mode is toggled.
#
sub _do_random {
    my ($self, $k, $h, $msg) = @_;

    my $mode = $msg->params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_post( 'random' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $mode = $msg->_data->random ? 0 : 1; # negate current value
    }

    $msg->_cooking ( $RAW );
    $msg->_commands( [ "random $mode" ] );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- MPD interaction: controlling playback

#
# event: play( [$song] )
#
# Begin playing playlist at song number $song. If no argument supplied,
# resume playing.
#
sub _do_play {
    my ($self, $k, $h, $msg) = @_;

    my $number = $msg->params->[0] // '';
    $msg->_commands ( [ "play $number" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: playid( [$song] )
#
# Begin playing playlist at song ID $song. If no argument supplied,
# resume playing.
#
sub _do_playid {
    my ($self, $k, $h, $msg) = @_;

    my $number = $msg->params->[0] // '';
    $msg->_commands ( [ "playid $number" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: pause( [$sate] )
#
# Pause playback. If $state is 0 then the current track is unpaused, if
# $state is 1 then the current track is paused.
#
# Note that if $state is not given, pause state will be toggled.
#
sub _do_pause {
    my ($self, $k, $h, $msg) = @_;

    my $state = $msg->params->[0] // '';
    $msg->_commands ( [ "pause $state" ] );
    $msg->_cooking  ( $RAW );
    $k->post( $h->{socket}, 'send', $msg );
}


=pod

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
    my $msg = $_[ARG0];
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ 'next' ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: prev()
#
# Play previous song in playlist.
#
sub _onpub_prev {
    my $msg = $_[ARG0];
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ 'previous' ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: seek( $time, [$song] )
#
# Seek to $time seconds in song number $song. If $song number is not specified
# then the perl module will try and seek to $time in the current song.
#
sub _onpub_seek {
    my ($k, $msg) = @_[KERNEL, ARG0];

    my ($time, $song) = @{ $msg->_params }[0,1];
    $time ||= 0; $time = int $time;
    if ( not defined $song )  {
        if ( not defined $msg->data ) {
            # no status yet - fire an event
            $msg->_dispatch  ( 'status' );
            $msg->_post_to   ( $MPD );
            $msg->_post_event( 'seek' );
            $k->post( $MPD, '_dispatch', $msg );
            return;
        }

        $song = $msg->data->song;
    }

    $msg->_cooking ( $RAW );
    $msg->_answer  ( $DISCARD );
    $msg->_commands( [ "seek $song $time" ] );
    $k->post( $_HUB, '_send', $msg );
}


#
# event: seekid( $time, [$songid] )
#
# Seek to $time seconds in song ID $songid. If $songid number is not specified
# then the perl module will try and seek to $time in the current song.
#
sub _onpub_seekid {
    my ($k, $msg) = @_[KERNEL, ARG0];

    my ($time, $songid) = @{ $msg->_params }[0,1];
    $time ||= 0; $time = int $time;
    if ( not defined $songid )  {
        if ( not defined $msg->data ) {
            # no status yet - fire an event
            $msg->_dispatch  ( 'status' );
            $msg->_post_to   ( $MPD );
            $msg->_post_event( 'seek' );
            $k->post( $MPD, '_dispatch', $msg );
            return;
        }

        $songid = $msg->data->songid;
    }

    $msg->_cooking ( $RAW );
    $msg->_answer  ( $DISCARD );
    $msg->_commands( [ "seekid $songid $time" ] );
    $k->post( $_HUB, '_send', $msg );
}

=cut

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
