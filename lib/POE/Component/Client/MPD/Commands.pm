use 5.010;
use strict;
use warnings;

package POE::Component::Client::MPD::Commands;
# ABSTRACT: module handling basic mpd commands

use Moose;
use MooseX::Has::Sugar;
use MooseX::Types::Moose qw{ Str };
use POE;

use POE::Component::Client::MPD::Message;

has socket => ( ro, required, isa=>Str );


# -- MPD interaction: general commands

=ev_mpd_ctrl version( )

Return mpd's version number as advertised during connection. Note that
mpd returns B<protocol> version when connected. This protocol version can
differ from the real mpd version. eg, mpd version 0.13.2 is "speaking"
and thus advertising version 0.13.0.

=cut

sub _do_version {
    my ($self, $k, $h, $msg) = @_;
    $msg->set_status(1);
    $k->post( $msg->_from, 'mpd_result', $msg, $h->{version} );
}


=ev_mpd_ctrl kill( )

Kill the mpd server, and request the pococm to be shutdown.

=cut

sub _do_kill {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'kill' ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
    $k->delay_set('disconnect'=>1);
}


=ev_mpd_ctrl updatedb( [$path] )

Force mpd to rescan its collection. If C<$path> (relative to MPD's music
directory) is supplied, MPD will only scan it - otherwise, MPD will
rescan its whole collection.

=cut

sub _do_updatedb {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';  # FIXME: padre//

    $msg->_set_commands( [ qq{update "$path"} ] );
    $msg->_set_cooking ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_ctrl urlhandlers( )

Return an array of supported URL schemes.

=cut

sub _do_urlhandlers {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'urlhandlers' ] );
    $msg->_set_cooking  ( 'strip_first' );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- MPD interaction: handling volume & output


=ev_mpd_output volume( $volume )

Sets the audio output volume percentage to absolute C<$volume>. If
C<$volume> is prefixed by '+' or '-' then the volume is changed
relatively by that value.

=cut

sub _do_volume {
    my ($self, $k, $h, $msg) = @_;

    my $volume;
    if ( $msg->params->[0] =~ /^(-|\+)(\d+)/ ) {
        my ($op, $delta) = ($1, $2);
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_set_post( 'volume' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        # already got a status result
        my $curvol = $msg->_data->volume;
        $volume = $op eq '+' ? $curvol + $delta : $curvol - $delta;
    } else {
        $volume = $msg->params->[0];
    }

    $msg->_set_commands ( [ "setvol $volume" ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_output output_enable( $output )

Enable the specified audio output. C<$output> is the ID of the audio
output.

=cut

sub _do_output_enable {
    my ($self, $k, $h, $msg) = @_;
    my $output = $msg->params->[0];

    $msg->_set_commands ( [ "enableoutput $output" ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_output output_disable( $output )

Disable the specified audio output. C<$output> is the ID of the audio output.

=cut

sub _do_output_disable {
    my ($self, $k, $h, $msg) = @_;
    my $output = $msg->params->[0];

    $msg->_set_commands ( [ "disableoutput $output" ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- MPD interaction: retrieving info from current state

=ev_mpd_info stats( )

Return an L<Audio::MPD::Common::Stats> object with the current
statistics of MPD.

=cut

sub _do_stats {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'stats' ] );
    $msg->_set_cooking  ( 'as_kv' );
    $msg->_set_transform( 'as_stats' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_info status( )

Return an L<Audio::MPD::Common::Status> object with the current
status of MPD.

=cut

sub _do_status {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'status' ] );
    $msg->_set_cooking  ( 'as_kv' );
    $msg->_set_transform( 'as_status' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_info current( )

Return an L<Audio::MPD::Common::Item::Song> representing the song
currently playing.

=cut

sub _do_current {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'currentsong' ] );
    $msg->_set_cooking  ( 'as_items' );
    $msg->_set_transform( 'as_scalar' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_info song( [$song] )

Return an L<Audio::MPD::Common::Item::Song> representing the song number
C<$song>. If C<$song> is not supplied, returns the current song.

=cut

sub _do_song {
    my ($self, $k, $h, $msg) = @_;
    my $song = $msg->params->[0];

    $msg->_set_commands ( [ defined $song ? "playlistinfo $song" : 'currentsong' ] );
    $msg->_set_cooking  ( 'as_items' );
    $msg->_set_transform( 'as_scalar' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_info songid( [$songid] )

Return an L<Audio::MPD::Common::Item::Song> representing the song id
C<$songid>. If C<$songid> is not supplied, returns the current song.

=cut

sub _do_songid {
    my ($self, $k, $h, $msg) = @_;
    my $song = $msg->params->[0];

    $msg->_set_commands ( [ defined $song ? "playlistid $song" : 'currentsong' ] );
    $msg->_set_cooking  ( 'as_items' );
    $msg->_set_transform( 'as_scalar' );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- MPD interaction: altering settings


=ev_mpd_settings repeat( [$repeat] )

Set the repeat mode to C<$repeat> (1 or 0). If C<$repeat> is not
specified then the repeat mode is toggled.

=cut

sub _do_repeat {
    my ($self, $k, $h, $msg) = @_;

    my $mode = $msg->params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_set_post( 'repeat' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $mode = $msg->_data->repeat ? 0 : 1; # negate current value
    }

    $msg->_set_cooking ( 'raw' );
    $msg->_set_commands( [ "repeat $mode" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_settings fade( [$seconds] )

Enable crossfading and set the duration of crossfade between songs. If
C<$seconds> is not specified or C<$seconds> is 0, then crossfading is
disabled.

=cut

sub _do_fade {
    my ($self, $k, $h, $msg) = @_;
    my $seconds = $msg->params->[0] // 0;  # FIXME: padre//

    $msg->_set_commands ( [ "crossfade $seconds" ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_settings random( [$random] )

Set the random mode to C<$random> (1 or 0). If C<$random> is not
specified then the random mode is toggled.

=cut

sub _do_random {
    my ($self, $k, $h, $msg) = @_;

    my $mode = $msg->params->[0];
    if ( defined $mode )  {
        $mode = $mode ? 1 : 0;   # force integer
    } else {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_set_post( 'random' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $mode = $msg->_data->random ? 0 : 1; # negate current value
    }

    $msg->_set_cooking ( 'raw' );
    $msg->_set_commands( [ "random $mode" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- MPD interaction: controlling playback

=ev_mpd_playback play( [$song] )

Begin playing playlist at song number C<$song>. If no argument supplied,
resume playing.

=cut

sub _do_play {
    my ($self, $k, $h, $msg) = @_;

    my $number = $msg->params->[0] // ''; # FIXME: padre//
    $msg->_set_commands ( [ "play $number" ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_playback playid( [$song] )

Begin playing playlist at song ID C<$song>. If no argument supplied,
resume playing.

=cut

sub _do_playid {
    my ($self, $k, $h, $msg) = @_;

    my $number = $msg->params->[0] // ''; # FIXME: padre//
    $msg->_set_commands ( [ "playid $number" ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_playback pause( [$sate] )

Pause playback. If C<$state> is 0 then the current track is unpaused, if
C<$state> is 1 then the current track is paused.

Note that if C<$state> is not given, pause state will be toggled.

=cut

sub _do_pause {
    my ($self, $k, $h, $msg) = @_;

    my $state = $msg->params->[0] // '';  # FIXME: padre//
    $msg->_set_commands ( [ "pause $state" ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_playback stop( )

Stop playback.

=cut

sub _do_stop {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'stop' ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_playback next( )

Play next song in playlist.

=cut

sub _do_next {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'next' ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_playback prev( )

Play previous song in playlist.

=cut

sub _do_prev {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'previous' ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_playback seek( $time, [$song] )

Seek to C<$time> seconds in song number C<$song>. If C<$song> number is
not specified then the perl module will try and seek to C<$time> in the
current song.

=cut

sub _do_seek {
    my ($self, $k, $h, $msg) = @_;

    my ($time, $song) = @{ $msg->params }[0,1];
    $time ||= 0; $time = int $time;
    if ( not defined $song )  {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_set_post( 'seek' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $song = $msg->_data->song;
    }

    $msg->_set_cooking ( 'raw' );
    $msg->_set_commands( [ "seek $song $time" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_mpd_playback seekid( $time, [$songid] )

Seek to C<$time> seconds in song ID C<$songid>. If C<$songid> number is
not specified then the perl module will try and seek to C<$time> in the
current song.

=cut

sub _do_seekid {
    my ($self, $k, $h, $msg) = @_;

    my ($time, $songid) = @{ $msg->params }[0,1];
    $time ||= 0; $time = int $time;
    if ( not defined $songid )  {
        if ( not defined $msg->_data ) {
            # no status yet - fire an event
            $msg->_set_post( 'seekid' );
            $h->{mpd}->_dispatch($k, $h, 'status', $msg);
            return;
        }

        $songid = $msg->_data->songid;
    }

    $msg->_set_cooking ( 'raw' );
    $msg->_set_commands( [ "seekid $songid $time" ] );
    $k->post( $h->{socket}, 'send', $msg );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DESCRIPTION

L<POE::Component::Client::MPD::Commands> is responsible for handling
general purpose commands. They are in a dedicated module to achieve
easier code maintenance.

To achieve those commands, send the corresponding event to the POCOCM
session you created: it will be responsible for dispatching the event
where it is needed. Under no circumstance should you call directly subs
or methods from this module directly.

Read POCOCM's pod to learn how to deal with answers from those commands.

Following is a list of general purpose events accepted by POCOCM.
