use 5.010;
use strict;
use warnings;

package POE::Component::Client::MPD::Playlist;
# ABSTRACT: module handling playlist commands

use Moose;
use MooseX::Has::Sugar;
use POE;

use POE::Component::Client::MPD::Message;

has mpd => ( ro, required, weak_ref, );# isa=>'POE::Component::Client::MPD' );


# -- Playlist: retrieving information

=ev_play_info pl.as_items( )

Return an array of L<Audio::MPD::Common::Item::Song>s, one for each of
the songs in the current playlist.

=cut

sub _do_as_items {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'playlistinfo' ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_info pl.items_changed_since( $plversion )

Return a list with all the songs (as L<Audio::MPD::Common::Item::Song>
objects) added to the playlist since playlist C<$plversion>.

=cut

sub _do_items_changed_since {
    my ($self, $k, $h, $msg) = @_;
    my $plid = $msg->params->[0];

    $msg->_set_commands ( [ "plchanges $plid" ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- Playlist: adding / removing songs


=ev_play_addrm pl.add( $path, $path, ... )

Add the songs identified by C<$path> (relative to MPD's music directory)
to the current playlist.

=cut

sub _do_add {
    my ($self, $k, $h, $msg) = @_;

    my $args   = $msg->params;
    my @pathes = @$args;         # args of the poe event
    my @commands = (             # build the commands
        'command_list_begin',
        map( qq{add "$_"}, @pathes ),
        'command_list_end',
    );
    $msg->_set_commands ( \@commands );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_addrm pl.delete( $number, $number, ... )

Remove song C<$number> (starting from 0) from the current playlist.

=cut

sub _do_delete {
    my ($self, $k, $h, $msg) = @_;

    my $args    = $msg->params;
    my @numbers = @$args;
    my @commands = (              # build the commands
        'command_list_begin',
        map( qq{delete $_}, reverse sort {$a<=>$b} @numbers ),
        'command_list_end',
    );
    $msg->_set_commands ( \@commands );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_addrm pl.deleteid( $songid, $songid, ... )

Remove the specified C<$songid> (as assigned by mpd when inserted in
playlist) from the current playlist.

=cut

sub _do_deleteid {
    my ($self, $k, $h, $msg) = @_;

    my $args    = $msg->params;
    my @songids = @$args;
    my @commands = (              # build the commands
        'command_list_begin',
        map( qq{deleteid $_}, @songids ),
        'command_list_end',
    );
    $msg->_set_commands ( \@commands );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_addrm clear( )

Remove all the songs from the current playlist.

=cut

sub _do_clear {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'clear' ] );
    $msg->_set_cooking  ( 'raw' );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_addrm crop( )

Remove all of the songs from the current playlist *except* the current one.

=cut

sub _do_crop {
    my ($self, $k, $h, $msg) = @_;

    if ( not defined $msg->_data ) {
        # no status yet - fire an event
        $msg->_set_post( 'pl.crop' );
        $h->{mpd}->_dispatch($h, 'status', $msg);
        return;
    }

    # now we know what to remove
    my $cur = $msg->_data->song;
    my $len = $msg->_data->playlistlength - 1;
    my @commands = (
        'command_list_begin',
        map( { $_ != $cur ? "delete $_" : '' } reverse 0..$len ),
        'command_list_end'
    );

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( \@commands );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- Playlist: changing playlist order


=ev_play_order pl.shuffle( )

Shuffle the current playlist.

=cut

sub _do_shuffle {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ 'shuffle' ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_order pl.swap( $song1, $song2 )

Swap positions of song number C<$song1> and C<$song2> in the current
playlist.

=cut

sub _do_swap {
    my ($self, $k, $h, $msg) = @_;
    my ($from, $to) = @{ $msg->params }[0,1];

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ "swap $from $to" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_order pl.swapid( $songid1, $songid2 )

Swap positions of song id C<$songid1> and C<$songid2> in the current
playlist.

=cut

sub _do_swapid {
    my ($self, $k, $h, $msg) = @_;
    my ($from, $to) = @{ $msg->params }[0,1];

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ "swapid $from $to" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_order pl.move( $song, $newpos )

Move song number C<$song> to the position C<$newpos>.

=cut

sub _do_move {
    my ($self, $k, $h, $msg) = @_;
    my ($song, $pos) = @{ $msg->params }[0,1];

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ "move $song $pos" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_order pl.moveid( $songid, $newpos )

Move song id C<$songid> to the position C<$newpos>.

=cut

sub _do_moveid {
    my ($self, $k, $h, $msg) = @_;
    my ($songid, $pos) = @{ $msg->params }[0,1];

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ "moveid $songid $pos" ] );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- Playlist: managing playlists


=ev_play_mgmt pl.load( $playlist )

Load list of songs from specified C<$playlist> file.

=cut

sub _do_load {
    my ($self, $k, $h, $msg) = @_;
    my $playlist = $msg->params->[0];

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ qq{load "$playlist"} ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_mgmt pl.save( $playlist )

Save the current playlist to a file called C<$playlist> in MPD's
playlist directory.

=cut

sub _do_save {
    my ($self, $k, $h, $msg) = @_;
    my $playlist = $msg->params->[0];

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ qq{save "$playlist"} ] );
    $k->post( $h->{socket}, 'send', $msg );
}


=ev_play_mgmt pl.rm( $playlist )

Delete playlist named C<$playlist> from MPD's playlist directory.

=cut

sub _do_rm {
    my ($self, $k, $h, $msg) = @_;
    my $playlist = $msg->params->[0];

    $msg->_set_cooking  ( 'raw' );
    $msg->_set_commands ( [ qq{rm "$playlist"} ] );
    $k->post( $h->{socket}, 'send', $msg );
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DESCRIPTION

L<POE::Component::Client::MPD::Playlist> is responsible for handling
general purpose commands. They are in a dedicated module to achieve
easier code maintenance.

To achieve those commands, send the corresponding event to the POCOCM
session you created: it will be responsible for dispatching the event
where it is needed. Under no circumstance should you call directly subs
or methods from this module directly.

Read L<POCOCM|POE::Component::Client::MPD>'s pod to learn how to deal
with answers from those commands.

Following is a list of playlist-related events accepted by POCOCM.
