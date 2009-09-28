#!perl

use strict;
use warnings;

use Test::More;

my @songs   = qw{
    title.ogg dir1/title-artist-album.ogg
    dir1/title-artist.ogg dir2/album.ogg
};
my $nbtests = 63;
my @tests   = (
    # [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ]

    #[ $PLAYLIST, 'pl.clear', [],      0, &check_success          ],
    [ 'pl.add',   \@songs, 0, \&check_success ],

    # play
    [ 'play',     [],      0, \&check_success ],
    [ 'status',   [],      0, \&check_play1   ],
    [ 'play',     [2],     0, \&check_success ],
    [ 'status',   [],      0, \&check_play2   ],

    # playid
    [ 'play',     [0],     0, \&check_success ],
    [ 'pause',    [],      0, \&check_success ],
    [ 'playid',   [],      0, \&check_success ],
    [ 'status',   [],      0, \&check_playid1 ],
    [ 'playid',   [1],     0, \&check_success ],
    [ 'status',   [],      0, \&check_playid2 ],

    # pause
    [ 'pause',    [1],     0, \&check_success ],
    [ 'status',   [],      0, \&check_pause1  ],
    [ 'pause',    [0],     0, \&check_success ],
    [ 'status',   [],      0, \&check_pause2  ],
    [ 'pause',    [],      0, \&check_success ],
    [ 'status',   [],      0, \&check_pause3  ],
    [ 'pause',    [],      0, \&check_success ],
    [ 'status',   [],      0, \&check_pause4  ],

    # stop
    [ 'stop',     [],      0, \&check_success ],
    [ 'status',   [],      0, \&check_stop    ],

    # prev / next
    [ 'play',     [1],     0, \&check_success ],
    [ 'pause',    [],      0, \&check_success ],
    [ 'next',     [],      0, \&check_success ],
    [ 'status',   [],      0, \&check_prev    ],
    [ 'prev',     [],      0, \&check_success ],
    [ 'status',   [],      0, \&check_next    ],

    # seek
    [ 'seek',     [1,2],   0, \&check_success ],
    [ 'pause',    [1],     1, \&check_success ],
    [ 'status',   [],      0, \&check_seek1   ],
    [ 'seek',     [],      0, \&check_success ],
    [ 'pause',    [1],     1, \&check_success ],
    [ 'status',   [],      0, \&check_seek2   ],
    [ 'seek',     [1],     0, \&check_success ],
    [ 'pause',    [1],     1, \&check_success ],
    [ 'status',   [],      0, \&check_seek3   ],

    # seekid
    [ 'seekid',   [1,1],   0, \&check_success ],
    [ 'status',   [],      0, \&check_seekid1 ],
    [ 'seekid',   [],      0, \&check_success ],
    [ 'pause',    [1],     1, \&check_success ],
    [ 'status',   [],      0, \&check_seekid2 ],
    [ 'seekid',   [1],     0, \&check_success ],
    [ 'pause',    [1],     1, \&check_success ],
    [ 'status',   [],      0, \&check_seekid3 ],
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

sub check_play1   { check_success($_[0]); is($_[1]->state,  'play',  'play() starts playback'); }
sub check_play2   { check_success($_[0]); is($_[1]->song,   2,       'play() can start playback at a given song'); }
sub check_playid1 { check_success($_[0]); is($_[1]->state,  'play',  'playid() starts playback'); }
sub check_playid2 { check_success($_[0]); is($_[1]->songid, 1,       'playid() can start playback at a given song'); }
sub check_pause1  { check_success($_[0]); is($_[1]->state,  'pause', 'pause() forces playback pause'); }
sub check_pause2  { check_success($_[0]); is($_[1]->state,  'play',  'pause() forces playback resume'); }
sub check_pause3  { check_success($_[0]); is($_[1]->state,  'pause', 'pause() toggles to pause'); }
sub check_pause4  { check_success($_[0]); is($_[1]->state,  'play',  'pause() toggles to play'); }
sub check_stop    { check_success($_[0]); is($_[1]->state,  'stop',  'stop() forces full stop'); }
sub check_prev    { check_success($_[0]); is($_[1]->song,   2,       'next() changes track to next one'); }
sub check_next    { check_success($_[0]); is($_[1]->song,   1,       'prev() changes track to previous one'); }
sub check_seek1 {
    my ($msg, $status) = @_;
    check_success($msg);
    is($status->song, 2, 'seek() can change the current track');
    TODO: {
        local $TODO = "detection method doesn't always work - depends on timing";
        is($status->time->sofar_secs, 1, 'seek() seeks in the song');
    }
}
sub check_seek2 {
    my ($msg, $status) = @_;
    check_success($msg);
    TODO: {
        local $TODO = "detection method doesn't always work - depends on timing";
        is($_[1]->time->sofar_secs, 0, 'seek() defaults to beginning of song');
    }
}
sub check_seek3 {
    my ($msg, $status) = @_;
    check_success($msg);
    TODO: {
        local $TODO = "detection method doesn't always work - depends on timing";
        is($_[1]->time->sofar_secs, 1, 'seek() defaults to current song ');
    }
}
sub check_seekid1 {
    my ($msg, $status) = @_;
    check_success($msg);
    is($status->songid, 1, 'seekid() can change the current track');
    TODO: {
        local $TODO = "detection method doesn't always work - depends on timing";
        is($status->time->sofar_secs, 1, 'seekid() seeks in the song');
    }
}
sub check_seekid2 {
    my ($msg, $status) = @_;
    check_success($msg);
    TODO: {
        local $TODO = "detection method doesn't always work - depends on timing";
        is($_[1]->time->sofar_secs, 0, 'seekid() defaults to beginning of song');
    }
}
sub check_seekid3 {
    my ($msg, $status) = @_;
    check_success($msg);
    TODO: {
        local $TODO = "detection method doesn't always work - depends on timing";
        is($_[1]->time->sofar_secs, 1, 'seekid() defaults to current song');
    }
}
