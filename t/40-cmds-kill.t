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
use POE::Component::Client::MPD;
use Test::More;

eval 'use POE::Component::Client::MPD::Test dont_start_poe=>1';
plan skip_all => $@ if $@ =~ s/\n+BEGIN failed--compilation aborted.*//s;
plan tests => 1;

POE::Component::Client::MPD->spawn( { alias => 'mpd' } );
my $id = POE::Session->create(
    inline_states => {
        _start    => \&_start,
        _check    => \&_check,
        _kill     => \&_kill,
    }
);
POE::Kernel->run;
exit;

#--

sub _start {
    my $k = $_[KERNEL];
    $k->alias_set('tester');      # refcount++
    $k->delay_set('_kill' => 0.5);  # FIXME: use connected event to start tests in pococm-test
}

sub _check {
    my @procs = grep { /\smpd\s/ } grep { !/grep/ } qx[ ps -ef ];
    is( scalar @procs, 0, 'kill shuts down mpd' );
}

sub _kill {
    my $k = $_[KERNEL];
    $k->delay_set('_check' => 1);
    $k->post('mpd', 'kill');
    $k->alias_remove('tester');      # refcount--
}

