#!perl

use 5.010;
use strict;
use warnings;

use POE qw{ Component::Client::MPD::Connection };
use Readonly;
use Test::More tests => 4;

Readonly my $ALIAS => 'tester';


my $max_retries = 3;
my $id = POE::Session->create(
    inline_states => {
        _start                      => \&_onpriv_start,
        mpd_connect_error_retriable => \&_onprot_mpd_connect_error_retriable,
        mpd_connect_error_fatal     => \&_onprot_mpd_connect_error_fatal,
    }
);
my $conn = POE::Component::Client::MPD::Connection->spawn( {
    host        => 'localhost',
    port        => 16600,
    id          => $id,
    retry_wait  => 0,
    max_retries => $max_retries,
} );
POE::Kernel->run;
exit;

#--

sub _onpriv_start {
    my ($k, $h) = @_[KERNEL, HEAP];
    $k->alias_set($ALIAS); # increment refcount
    $h->{count} = 0;
}

sub _onprot_mpd_connect_error_retriable {
    my ($k, $h, $errstr) = @_[KERNEL, HEAP, ARG0];
    like($errstr, qr/^connect: \(\d+\) /, 'retriable error trapped');
    $h->{count}++;
}

sub _onprot_mpd_connect_error_fatal {
    my ($k, $h, $errstr) = @_[KERNEL, HEAP, ARG0];

    # checks
    is($h->{count}, $max_retries-1, 'retriable errors are tried again $max_retries times');
    like($errstr, qr/^Too many failed attempts!/, 'too many errors lead to fatal error');

    # cleanup
    $k->post($conn, 'disconnect');
    $k->alias_remove($ALIAS); # decrement refcount
}


