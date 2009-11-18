use 5.010;
use strict;
use warnings;

package POE::Component::Client::MPD::Test;
# ABSTRACT: automate launching of fake mdp for testing purposes

use Moose 0.92;
use MooseX::Has::Sugar;
use MooseX::POE;
use MooseX::SemiAffordanceAccessor;
use MooseX::Types::Moose qw{ ArrayRef Str };
use POE;
use Readonly;

Readonly my $K => $poe_kernel;

has alias => ( ro, isa=>Str, default=>'tester' );
has tests => (
    ro, auto_deref, required,
    isa=>ArrayRef,
    traits     => ['Array'],
    handles    => {
        #tests => 'elements',
        get_test  => 'get',
        pop_test => 'shift',
        nbtests   => 'count',
    },
);


# -- builders & initializer

#
# START()
#
# called as poe session initialization
#
sub START {
    my $self = shift;
    $K->alias_set($self->alias);     # refcount++
    $K->yield( 'next_test' );        # launch the first test.
}


# -- public events

#
# event: next_test()
#
# Called to schedule the next test.
#
event next_test => sub {
    my $self = shift;

    if ( $self->nbtests == 0 ) { # no more tests.
        $K->alias_remove( $self->alias );
        $K->post('mpd', 'disconnect');
        return;
    }

    # post next event.
    my $test = $self->get_test(0);
    my $event = $test->[0];
    my $args  = $test->[1];
    $K->post( 'mpd', $event, @$args );
};


#
# event: mpd_result( $msg )
#
# Called when mpd talks back, with $msg as a pococm-message param.
#
event mpd_result => sub {
    my ($self, $msg, $results) = @_[OBJECT, ARG0, ARG1];
    my $test = $self->get_test(0);
    $test->[3]->($msg, $results);             # check if everything went fine
    $K->delay_set('next_test'=>$test->[2]);   # call next test after some time
    $self->pop_test;                          # remove test being played
};


1;

__END__

=for Pod::Coverage::TrustPod
    START

=head1 SYNOPSIS

    POE::Component::Client::MPD::Test->new( tests => [
        [ 'event', [ $arg1, $arg2, ... ], $sleep, \&check_results ],
        ...
    ] );


=head1 DESCRIPTION

=head2 General usage

This module will try to launch a new mpd server for testing purposes. This
mpd server will then be used during POE::Component::Client::MPD tests.

In order to achieve this, the module will create a fake mpd.conf file with
the correct pathes (ie, where you untarred the module tarball). It will then
check if some mpd server is already running, and stop it if the
MPD_TEST_OVERRIDE environment variable is true (die otherwise). Last it will
run the test mpd with its newly created configuration file.

Everything described above is done automatically when the module is C<use>-d.


Once the tests are run, the mpd server will be shut down, and the original
one will be relaunched (if there was one).

Note that the test mpd will listen to C<localhost>, so you are on the safe
side. Note also that the test suite comes with its own ogg files - and yes,
we can redistribute them since it's only some random voice recordings :-)


