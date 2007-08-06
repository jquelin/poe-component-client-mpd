#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;

use POE;
use POE::Component::Client::MPD qw[ :all ];
use POE::Component::Client::MPD::Message;
use Readonly;
use Test::More;


our $nbtests = 8;
our @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $answer_back, \&check_results ]

    # all_albums
    [ $COLLECTION, 'all_albums',  [], $SEND, \&check_all_albums ],

    # all_artists
    [ $COLLECTION, 'all_artists', [], $SEND, \&check_all_artists ],

    # all_titles
    [ $COLLECTION, 'all_titles',  [], $SEND, \&check_all_titles ],

    # all_files
    [ $COLLECTION, 'all_files',   [], $SEND, \&check_all_files ],

);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

sub check_all_albums {
    my @list = @{ $_[0]->data };
    is( scalar @list, 1, 'all_albums return the albums' );
    is( $list[0], 'our album', 'all_albums return strings' );
}

sub check_all_artists {
    my @list = @{ $_[0]->data };
    is( scalar @list, 1, 'all_artists return the artists' );
    is( $list[0], 'dir1-artist', 'all_artists return strings' );
}

sub check_all_titles {
    my @list = @{ $_[0]->data };
    is( scalar @list, 3, 'all_titles return the titles' );
    like( $list[0], qr/-title$/, 'all_titles return strings' );
}


sub check_all_files {
    my $list = $_[0]->data;
    is( scalar @$list, 4, 'all_files return the pathes' );
    like( $list->[0], qr/\.ogg$/, 'all_files return strings' );
}
