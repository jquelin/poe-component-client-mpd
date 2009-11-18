#!perl

use 5.010;
use strict;
use warnings;

use Test::More;

my $nb;
my @songs   = qw{
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
};
my $nbtests = 26;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    # delete / deleteid
    # should come first to be sure songid #0 is really here.
    [ 'pl.clear',              [], 0, \&check_success ],
    [ 'pl.add',           \@songs, 0, \&check_success ],
    [ 'status',                [], 0, \&get_nb        ],
    [ 'pl.delete',          [1,2], 0, \&check_success ],
    [ 'status',                [], 0, \&check_del     ],
    [ 'status',                [], 0, \&get_nb        ],
    [ 'pl.deleteid',          [0], 0, \&check_success ],
    [ 'status',                [], 0, \&check_delid   ],

    # add
    [ 'pl.clear',              [], 0, \&check_success ],
    [ 'status',                [], 0, \&get_nb        ],
    [ 'pl.add',   [ 'title.ogg' ], 0, \&check_success ],
    [ 'pl.add',           \@songs, 0, \&check_success ],
    [ 'status',                [], 0, \&check_add     ],

    # clear
    [ 'pl.add',           \@songs, 0, \&check_success ],
    [ 'pl.clear',              [], 0, \&check_success ],
    [ 'status',                [], 0, \&check_clear   ],

    # crop
    [ 'pl.add',           \@songs, 0, \&check_success ],
    [ 'play',                 [1], 0, \&check_success ], # to set song
    [ 'stop',                  [], 0, \&check_success ],
    [ 'pl.crop',               [], 1, \&check_success ],
    [ 'status',                [], 0, \&check_crop    ],

);


# are we able to test module?
eval 'use POE::Component::Client::MPD::Test nbtests=>$nbtests, tests=>\@tests';
diag($@), plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
exit;

#--

sub check_success {
    my ($msg) = @_;
    is($msg->status, 1, "command '" . $msg->request . "' returned an ok status");
}

sub get_nb      { check_success($_[0]); $nb = $_[1]->playlistlength }
sub check_add   { check_success($_[0]); is($_[1]->playlistlength, $nb+5, 'add() songs'); }
sub check_del   { check_success($_[0]); is($_[1]->playlistlength, $nb-2, 'delete() songs'); }
sub check_delid { check_success($_[0]); is($_[1]->playlistlength, $nb-1, 'deleteid() songs'); }
sub check_clear { check_success($_[0]); is($_[1]->playlistlength, 0, 'clear() leaves 0 song'); }
sub check_crop  { check_success($_[0]); is($_[1]->playlistlength, 1, 'crop() leaves only 1 song'); }
