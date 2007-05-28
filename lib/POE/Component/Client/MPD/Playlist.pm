#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Playlist;

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Message;
use base qw[ Class::Accessor::Fast ];

# -- Playlist: retrieving information

#
# event: pl.as_items()
#
# Return an array of C<POCOCM::Item::Song>s, one for each of the
# songs in the current playlist.
#
sub _onpub_as_items {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ 'playlistinfo' ],
        _cooking  => $AS_ITEMS,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.items_changed_since( $plversion )
#
# Return a list with all the songs (as POCOM::Item::Song objects) added to
# the playlist since playlist $plversion.
#
sub _onpub_items_changed_since {
    my $plid = $_[ARG0];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $SEND,
        _commands => [ "plchanges $plid" ],
        _cooking  => $AS_ITEMS,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- Playlist: adding / removing songs

#
# event: pl.add( $path, $path, ... )
#
# Add the songs identified by $path (relative to MPD's music directory) to
# the current playlist.
# No return event.
#
sub _onpub_add {
    my @pathes   = @_[ARG0 .. $#_];    # args of the poe event
    my @commands = (                   # build the commands
        'command_list_begin',
        map( qq[add "$_"], @pathes ),
        'command_list_end',
    );
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => \@commands,
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.delete( $number, $number, ... )
#
# Remove song $number (starting from 0) from the current playlist.
# No return event.
#
sub _onpub_delete {
    my @numbers  = @_[ARG0 .. $#_];    # args of the poe event
    my @commands = (                   # build the commands
        'command_list_begin',
        map( qq[delete $_], reverse sort {$a<=>$b} @numbers ),
        'command_list_end',
    );
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => \@commands,
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.deleteid( $songid, $songid, ... )
#
# Remove the specified $songid (as assigned by mpd when inserted in playlist)
# from the current playlist.
#
sub _onpub_deleteid {
    my @songids  = @_[ARG0 .. $#_];    # args of the poe event
    my @commands = (                   # build the commands
        'command_list_begin',
        map( qq[deleteid $_], @songids ),
        'command_list_end',
    );
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => \@commands,
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: clear()
#
# Remove all the songs from the current playlist.
#
sub _onpub_clear {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ 'clear' ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: crop()
#
#  Remove all of the songs from the current playlist *except* the current one.
#
sub _onpub_crop {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from      => $_[SENDER]->ID,
        _request   => $_[STATE],
        _answer    => $DISCARD,
        _cooking   => $RAW,
        _pre_from  => '_crop_status',
        _pre_event => 'status',
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: _crop_status( $msg, $status)
#
# Use $status to get current song, before sending real crop $msg.
#
sub _onpriv_crop_status {
    my ($msg, $status) = @_[ARG0, ARG1];
    my $cur = $status->data->song;
    my $len = $status->data->playlistlength - 1;

    my @commands = (
        'command_list_begin',
        map( { $_  != $cur ? "delete $_" : '' } reverse 0..$len ),
        'command_list_end'
    );
    $msg->_commands( \@commands );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- Playlist: changing playlist order

#
# event: pl.shuffle()
#
# Shuffle the current playlist.
#
sub _onpub_shuffle {
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ 'shuffle' ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.swap( $song1, song2 )
#
# Swap positions of song number $song1 and $song2 in the current playlist.
#
sub _onpub_swap {
    my ($from, $to) = @_[ARG0, ARG1];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "swap $from $to" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.swapid( $songid1, songid2 )
#
# Swap positions of song id $songid1 and $songid2 in the current playlist.
#
sub _onpub_swapid {
    my ($from, $to) = @_[ARG0, ARG1];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "swapid $from $to" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.move( $song, $newpos );
#
# Move song number $song to the position $newpos.
#
sub _onpub_move {
    my ($song, $pos) = @_[ARG0, ARG1];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "move $song $pos" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.moveid( $songid, $newpos );
#
# Move song id $songid to the position $newpos.
#
sub _onpub_moveid {
    my ($songid, $pos) = @_[ARG0, ARG1];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "moveid $songid $pos" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


# -- Playlist: managing playlists

#
# event: pl.load( $playlist );
#
# Load list of songs from specified $playlist file.
#
sub _onpub_load {
    my ($playlist) = $_[ARG0];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "load $playlist" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.save( $playlist );
#
# Save the current playlist to a file called $playlist in MPD's
# playlist directory.
#
sub _onpub_save {
    my ($playlist) = $_[ARG0];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ "save $playlist" ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


1;

__END__

=head1 NAME

POE::Component::Client::MPD::Playlist - module handling playlist commands


=head1 DESCRIPTION

C<POCOCM::Playlist> is responsible for handling playlist-related commands.
To achieve those commands, send the corresponding event to the POCOCM
session you created: it will be responsible for dispatching the event
where it is needed.


=head1 PUBLIC EVENTS

The following is a list of general purpose events accepted by POCOCM.


=head2 Retrieving information

=head2 Adding / removing songs

=head2 Changing playlist order

=head2 Managing playlists


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
