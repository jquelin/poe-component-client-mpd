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

package POE::Component::Client::MPD::Commands;

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Message;
use POE::Component::Client::MPD::Stats;
use POE::Component::Client::MPD::Status;
use base qw[ Class::Accessor::Fast ];

# -- MPD interaction: general commands

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


# -- MPD interaction: handling volume & output

#
# event: volume( $volume )
#
# Sets the audio output volume percentage to absolute $volume.
# If $volume is prefixed by '+' or '-' then the volume is changed relatively
# by that value.
#
sub _onpub_volume {
    my $volume = $_[ARG0]; # FIXME: +/- prefix
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "setvol $volume" ],
        _cooking  => $RAW,
    } );
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
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ 'stats' ],
        _cooking  => $AS_KV,
        _post     => '_stats_postback',
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _stats_postback( $msg )
#
# Transform $msg->data from hash to a POCOCM::Stats object with the current
# statistics of MPD.
#
sub _onpriv_stats_postback {
    my $msg   = $_[ARG0];
    my %stats = @{ $msg->data };
    my $stats = POE::Component::Client::MPD::Stats->new( \%stats );
    $msg->data($stats);
    $_[KERNEL]->yield( '_mpd_data', $msg );
}


#
# event: status()
#
# Return a hash with the current status of MPD.
#
sub _onpub_status {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ 'status' ],
        _cooking  => $AS_KV,
        _post     => '_status_postback',
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _status_postback( $msg )
#
# Transform $msg->data from hash to a POCOCM::Status object with the current
# status of MPD.
#
sub _onpriv_status_postback {
    my $msg   = $_[ARG0];
    my %stats = @{ $msg->data };
    my $stats = POE::Component::Client::MPD::Status->new( \%stats );
    $msg->data($stats);
    $_[KERNEL]->yield( '_mpd_data', $msg );
}


#
# event: current()
#
# Return a POCOCM::Item::Song representing the song currently playing.
#
sub _onpub_current {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ 'currentsong' ],
        _cooking  => $AS_ITEMS,
        _post     => '_post_array2scalar',
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- MPD interaction: altering settings
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
