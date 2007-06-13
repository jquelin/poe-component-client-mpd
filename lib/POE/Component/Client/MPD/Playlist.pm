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
use POE::Component::Client::MPD qw[ :all ];
use POE::Component::Client::MPD::Message;
use Readonly;

use base qw[ Class::Accessor::Fast ];

Readonly my @EVENTS => qw[ add clear crop delete deleteid ];


sub _spawn {
    my $object = __PACKAGE__->new;
    my $session = POE::Session->create(
        inline_states => {
            '_start'      => sub { warn "started: $PLAYLIST (" . $_[SESSION]->ID . ")\n"; $_[KERNEL]->alias_set( $PLAYLIST ) },
            '_stop'       => sub { warn "stopped: $PLAYLIST\n";  },
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
    my $msg = $_[ARG0];

    my $args   = $msg->_params;
    my @pathes = @$args;         # args of the poe event
    my @commands = (             # build the commands
        'command_list_begin',
        map( qq[add "$_"], @pathes ),
        'command_list_end',
    );
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( \@commands );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: pl.delete( $number, $number, ... )
#
# Remove song $number (starting from 0) from the current playlist.
# No return event.
#
sub _onpub_delete {
    my $msg = $_[ARG0];

    my $args    = $msg->_params;
    my @numbers = @$args;         # args of the poe event
    my @commands = (              # build the commands
        'command_list_begin',
        map( qq[delete $_], reverse sort {$a<=>$b} @numbers ),
        'command_list_end',
    );
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( \@commands );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: pl.deleteid( $songid, $songid, ... )
#
# Remove the specified $songid (as assigned by mpd when inserted in playlist)
# from the current playlist.
#
sub _onpub_deleteid {
    my $msg = $_[ARG0];

    my $args    = $msg->_params;
    my @songids = @$args;         # args of the poe event
    my @commands = (              # build the commands
        'command_list_begin',
        map( qq[deleteid $_], @songids ),
        'command_list_end',
    );
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( \@commands );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: clear()
#
# Remove all the songs from the current playlist.
#
sub _onpub_clear {
    my $msg = $_[ARG0];
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( [ 'clear' ] );
    $msg->_cooking  ( $RAW );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: crop()
#
#  Remove all of the songs from the current playlist *except* the current one.
#
sub _onpub_crop {
    my ($k, $msg) = @_[KERNEL, ARG0];

    if ( not defined $msg->data ) {
        # no status yet - fire an event
        $msg->_dispatch  ( 'status' );
        $msg->_post_to   ( $PLAYLIST );
        $msg->_post_event( 'crop' );
        $k->post( $MPD, '_dispatch', $msg );
        return;
    }

    # now we know what to remove
    my $cur = $msg->data->song;
    my $len = $msg->data->playlistlength - 1;
    my @commands = (
        'command_list_begin',
        map( { $_  != $cur ? "delete $_" : '' } reverse 0..$len ),
        'command_list_end'
    );

    $msg->_cooking  ( $RAW );
    $msg->_answer   ( $DISCARD );
    $msg->_commands ( \@commands );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
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
        _commands => [ qq[load "$playlist"] ],
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
        _commands => [ qq[save "$playlist"] ],
        _cooking  => $RAW,
    } );
    $_[KERNEL]->yield( '_send', $msg );
}


#
# event: pl.save( $playlist );
#
# Delete playlist named $playlist from MPD's playlist directory.
#
sub _onpub_rm {
    my ($playlist) = $_[ARG0];
    my $msg = POE::Component::Client::MPD::Message->new( {
        _from     => $_[SENDER]->ID,
        _request  => $_[STATE],
        _answer   => $DISCARD,
        _commands => [ qq[rm "$playlist"] ],
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
