#!perl

use 5.010;
use strict;
use warnings;

use POE qw{ Component::Client::MPD::Connection };
use Readonly;
use Test::More;

my $sendmail_running = grep { /:25\s.*LISTEN/ } qx{ netstat -an };
plan skip_all => 'need some sendmail server running' unless $sendmail_running;
plan tests => 1;

Readonly my $ALIAS => 'tester';

my $id = POE::Session->create(
    inline_states => {
        _start                  => \&_onpriv_start,
        mpd_connect_error_fatal => \&_onpriv_mpd_connect_error_fatal,
    }
);
my $conn = POE::Component::Client::MPD::Connection->spawn( {
    host => 'localhost',
    port => 25,
    id   => $id,
} );
POE::Kernel->run;
exit;

#--

sub _onpriv_start {
    $_[KERNEL]->alias_set($ALIAS); # increment refcount
}

sub _onpriv_mpd_connect_error_fatal {
    my ($k, $arg) = @_[KERNEL, ARG0];
    like($arg, qr/^Not a mpd server - welcome string was:/, 'wrong server');
    $k->alias_remove($ALIAS); # increment refcount
    $k->post($conn, 'disconnect');
}
