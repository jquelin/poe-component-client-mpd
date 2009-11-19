use 5.010;
use strict;
use warnings;

package POE::Component::Client::MPD::Collection;
# ABSTRACT: module handling collection commands

use POE;
use POE::Component::Client::MPD::Message;

use base qw{ Class::Accessor::Fast };


# -- Collection: retrieving songs & directories

#
# event: coll.all_items( [$path] )
#
# Return *all* Audio::MPD::Common::Items (both songs & directories)
# currently known by mpd.
#
# If $path is supplied (relative to mpd root), restrict the retrieval to
# songs and dirs in this directory.
#
sub _do_all_items {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';

    $msg->_set_commands ( [ qq{listallinfo "$path"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.all_items_simple( [$path] )
#
# Return *all* Audio::MPD::Common::Items (both songs & directories)
# currently known by mpd.
#
# If $path is supplied (relative to mpd root), restrict the retrieval to
# songs and dirs in this directory.
#
# /!\ Warning: the Audio::MPD::Common::Item::Song objects will only have
# their attribute file filled. Any other attribute will be empty, so
# don't use this sub for any other thing than a quick scan!
#
sub _do_all_items_simple {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';

    $msg->_set_commands ( [ qq{listall "$path"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.items_in_dir( [$path] )
#
# Return the items in the given $path. If no $path supplied, do it on mpd's
# root directory.
# Note that this sub does not work recusrively on all directories.
#
sub _do_items_in_dir {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';

    $msg->_set_commands ( [ qq{lsinfo "$path"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- Collection: retrieving the whole collection


# event: coll.all_songs()
# FIXME?

#
# event: coll.all_albums()
#
# Return the list of all albums (strings) currently known by mpd.
#
sub _do_all_albums {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'list album' ] );
    $msg->_set_cooking  ( 'strip_first' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.all_artists()
#
# Return the list of all artists (strings) currently known by mpd.
#
sub _do_all_artists {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'list artist' ] );
    $msg->_set_cooking  ( 'strip_first' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.all_titles()
#
# Return the list of all titles (strings) currently known by mpd.
#
sub _do_all_titles {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'list title' ] );
    $msg->_set_cooking  ( 'strip_first' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.all_files()
#
# Return a mpd_result event with the list of all filenames (strings)
# currently known by mpd.
#
sub _do_all_files {
    my ($self, $k, $h, $msg) = @_;

    $msg->_set_commands ( [ 'list filename' ] );
    $msg->_set_cooking  ( 'strip_first' );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- Collection: picking songs

#
# event: coll.song( $path )
#
# Return the AMC::Item::Song which correspond to $path.
#
sub _do_song {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{find filename "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $msg->_set_transform( 'as_scalar' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.songs_with_filename_partial( $string )
#
# Return the AMC::Item::Songs containing $string in their path.
#
sub _do_songs_with_filename_partial {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{search filename "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


# -- Collection: songs, albums & artists relations

#
# event: coll.albums_by_artist( $artist )
#
# Return all albums (strings) performed by $artist or where $artist
# participated.
#
sub _do_albums_by_artist {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{list album "$what"} ] );
    $msg->_set_cooking  ( 'strip_first' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.songs_by_artist( $artist )
#
# Return all AMC::Item::Songs performed by $artist.
#
sub _do_songs_by_artist {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{find artist "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.songs_by_artist_partial( $artist )
#
# Return all AMC::Item::Songs performed by $artist.
#
sub _do_songs_by_artist_partial {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{search artist "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.songs_from_album( $album )
#
# Return all AMC::Item::Songs appearing in $album.
#
sub _do_songs_from_album {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{find album "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.songs_from_album_partial( $string )
#
# Return all AMC::Item::Songs appearing in album containing $string.
#
sub _do_songs_from_album_partial {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{search album "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.songs_with_title( $title )
#
# Return all AMC::Item::Songs which title is exactly $title.
#
sub _do_songs_with_title {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{find title "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


#
# event: coll.songs_with_title_partial( $string )
#
# Return all AMC::Item::Songs where $string is part of the title.
#
sub _do_songs_with_title_partial {
    my ($self, $k, $h, $msg) = @_;
    my $what = $msg->params->[0];

    $msg->_set_commands ( [ qq{search title "$what"} ] );
    $msg->_set_cooking  ( 'as_items' );
    $k->post( $h->{socket}, 'send', $msg );
}


1;

__END__

=head1 DESCRIPTION

L<POE::Component::Client::MPD::Collection> is responsible for handling
general purpose commands. They are in a dedicated module to achieve
easier code maintenance.

To achieve those commands, send the corresponding event to the
L<POE::Component::Client::MPD> session you created: it will be
responsible for dispatching the event where it is needed. Under no
circumstance should you call directly subs or methods from this
module directly.

Read L<POE::Component::Client::MPD>'s pod to learn how to deal with
answers from those commands.



=head1 PUBLIC EVENTS

The following is a list of collection-related events accepted by POCOCM.


=head2 Retrieving songs & directories


=over 4

=item * coll.all_items( [$path] )

Return all L<Audio::MPD::Common::Item>s (both songs & directories)
currently known by mpd.

If C<$path> is supplied (relative to mpd root), restrict the retrieval to
songs and dirs in this directory.


=item * coll.all_items_simple( [$path] )

Return all L<Audio::MPD::Common::Item>s (both songs & directories)
currently known by mpd.

If C<$path> is supplied (relative to mpd root), restrict the retrieval
to songs and dirs in this directory.

B</!\ Warning>: the L<Audio::MPD::Common::Item::Song> objects will only
have their attribute file filled. Any other attribute will be empty, so
don't use this sub for any other thing than a quick scan!


=item * coll.items_in_dir( [$path] )

Return the items in the given C<$path>. If no C<$path> supplied, do it on mpd's
root directory.

Note that this sub does not work recusrively on all directories.


=back



=head2 Retrieving the whole collection


=over 4

=item * coll.all_albums()

Return the list of all albums (strings) currently known by mpd.


=item * coll.all_artists()

Return the list of all artists (strings) currently known by mpd.


=item * coll.all_titles()

Return the list of all titles (strings) currently known by mpd.


=item * coll.all_files()

Return a mpd_result event with the list of all filenames (strings)
currently known by mpd.


=back



=head2 Picking songs


=over 4

=item * coll.song( $path )

Return the L<Audio::MPD::Common::Item::Song> which correspond to
C<$path>.


=item * coll.songs_with_filename_partial( $string )

Return the L<Audio::MPD::Common::Item::Song>s containing C<$string> in
their path.


=back



=head2 Songs, albums & artists relations


=over 4

=item * coll.albums_by_artist( $artist )

Return all albums (strings) performed by C<$artist> or where C<$artist>
participated.


=item * coll.songs_by_artist( $artist )

Return all L<Audio::MPD::Common::Item::Song>s performed by C<$artist>.


=item * coll.songs_by_artist_partial( $artist )

Return all L<Audio::MPD::Common::Item::Song>s performed by C<$artist>.


=item * coll.songs_from_album( $album )

Return all L<Audio::MPD::Common::Item::Song>s appearing in C<$album>.


=item * coll.songs_from_album_partial( $string )

Return all L<Audio::MPD::Common::Item::Song>s appearing in album
containing C<$string>.


=item * coll.songs_with_title( $title )

Return all L<Audio::MPD::Common::Item::Song>s which title is exactly
C<$title>.


=item * coll.songs_with_title_partial( $string )

Return all L<Audio::MPD::Common::Item::Song>s where C<$string> is part
of the title.


=back

