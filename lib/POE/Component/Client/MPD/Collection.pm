#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Collection;

use 5.010;
use strict;
use warnings;

use POE;
use POE::Component::Client::MPD::Message;

use base qw[ Class::Accessor::Fast ];

=pod

Readonly my @EVENTS => qw[
    all_items all_items_simple items_in_dir
    all_albums all_artists all_titles all_files
    song songs_with_filename_partial
    albums_by_artist
        songs_by_artist  songs_by_artist_partial
        songs_from_album songs_from_album_partial
        songs_with_title songs_with_title_partial
];

sub _spawn {
    my $object = __PACKAGE__->new;
    my $session = POE::Session->create(
        inline_states => {
            '_start'      => sub { $_[KERNEL]->alias_set( $COLLECTION ) },
            '_default'    => \&POE::Component::Client::MPD::_onpub_default,
            '_dispatch'   => \&_onpriv_dispatch,
            '_disconnect' => sub { $_[KERNEL]->alias_remove( $COLLECTION ) },
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

# -- Collection: retrieving songs & directories

#
# event: coll.all_items( [$path] )
#
# Return *all* Audio::MPD::Common::Items (both songs & directories)
# currently known by mpd.
# If $path is supplied (relative to mpd root), restrict the retrieval to
# songs and dirs in this directory.
#
sub _do_all_items {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';

    $msg->_commands ( [ qq[listallinfo "$path"] ] );
    $msg->_cooking  ( $AS_ITEMS );
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
# their tag file filled. Any other tag will be empty, so don't use this
# sub for any other thing than a quick scan!
#
sub _do_all_items_simple {
    my ($self, $k, $h, $msg) = @_;
    my $path = $msg->params->[0] // '';

    $msg->_commands ( [ qq[listall "$path"] ] );
    $msg->_cooking  ( $AS_ITEMS );
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

    $msg->_commands ( [ qq[lsinfo "$path"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $k->post( $h->{socket}, 'send', $msg );
}



# -- Collection: retrieving the whole collection


=pod

# event: coll.all_songs( )

#
# event: coll.all_albums( )
#
# Return the list of all albums (strings) currently known by mpd.
#
sub _onpub_all_albums {
    my $msg  = $_[ARG0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ 'list album' ] );
    $msg->_cooking  ( $STRIP_FIRST );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.all_artists( )
#
# Return the list of all artists (strings) currently known by mpd.
#
sub _onpub_all_artists {
    my $msg  = $_[ARG0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ 'list artist' ] );
    $msg->_cooking  ( $STRIP_FIRST );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.all_titles( )
#
# Return the list of all titles (strings) currently known by mpd.
#
sub _onpub_all_titles {
    my $msg  = $_[ARG0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ 'list title' ] );
    $msg->_cooking  ( $STRIP_FIRST );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.all_files()
#
# Return a mpd_result event with the list of all filenames (strings)
# currently known by mpd.
#
sub _onpub_all_files {
    my $msg  = $_[ARG0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ 'list filename' ] );
    $msg->_cooking  ( $STRIP_FIRST );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}

=cut

# -- Collection: picking songs

=pod

#
# event: coll.song( $path )
#
# Return the AMC::Item::Song which correspond to $path.
#
sub _onpub_song {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[find filename "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $msg->_transform( $AS_SCALAR );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.songs_with_filename_partial( $string );
#
# Return the AMC::Item::Songs containing $string in their path.
#
sub _onpub_songs_with_filename_partial {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[search filename "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


# -- Collection: songs, albums & artists relations

#
# event: coll.albums_by_artist($artist);
#
# Return all albums (strings) performed by $artist or where $artist
# participated.
#
sub _onpub_albums_by_artist {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[list album "$what"] ] );
    $msg->_cooking  ( $STRIP_FIRST );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.songs_by_artist($artist);
#
# Return all AMC::Item::Songs performed by $artist.
#
sub _onpub_songs_by_artist {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[find artist "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.songs_by_artist_partial($artist);
#
# Return all AMC::Item::Songs performed by $artist.
#
sub _onpub_songs_by_artist_partial {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[search artist "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.songs_from_album($album);
#
# Return all AMC::Item::Songs appearing in $album.
#
sub _onpub_songs_from_album {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[find album "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.songs_from_album_partial($string);
#
# Return all AMC::Item::Songs appearing in album containing $string.
#
sub _onpub_songs_from_album_partial {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[search album "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.songs_with_title($title);
#
# Return all AMC::Item::Songs which title is exactly $title.
#
sub _onpub_songs_with_title {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[find title "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}


#
# event: coll.songs_with_title_partial($string);
#
# Return all AMC::Item::Songs where $string is part of the title.
#
sub _onpub_songs_with_title_partial {
    my $msg  = $_[ARG0];
    my $what = $msg->_params->[0];
    $msg->_answer   ( $SEND );
    $msg->_commands ( [ qq[search title "$what"] ] );
    $msg->_cooking  ( $AS_ITEMS );
    $_[KERNEL]->post( $_HUB, '_send', $msg );
}

=cut

1;

__END__

=head1 NAME

POE::Component::Client::MPD::Collection - module handling collection commands


=head1 DESCRIPTION

C<POCOCM::Collection> is responsible for handling collection-related
commands. To achieve those commands, send the corresponding event to
the POCOCM session you created: it will be responsible for dispatching
the event where it is needed.


=head1 PUBLIC EVENTS

The following is a list of general purpose events accepted by POCOCM.


=head2 Retrieving songs & directories

=head2 Retrieving the whole collection

=head2 Picking songs

=head2 Songs, albums & artists relations


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
