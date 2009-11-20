use 5.010;
use strict;
use warnings;

package POE::Component::Client::MPD::Message;
# ABSTRACT: a message from POCOCM

use Moose;
use MooseX::Has::Sugar;
use MooseX::SemiAffordanceAccessor;
use MooseX::Types::Moose qw{ ArrayRef Bool Str };

use POE::Component::Client::MPD::Types;

has request => ( ro, required, isa=>'Maybe[Str]' );
has params  => ( ro, required, isa=>ArrayRef );
has status  => ( rw, isa=>Bool );

has _data      => ( rw );
has _commands  => ( rw, isa=>ArrayRef );
has _cooking   => ( rw, isa=>'Cooking' );
has _transform => ( rw, isa=>'Transform' );
has _post      => ( rw, isa=>'Maybe[Str]' );
has _from      => ( rw, isa=>Str );

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 SYNOPSIS

    print $msg->data . "\n";


=head1 DESCRIPTION

L<POE::Component::Client::MPD::Message> is more a placeholder for a hash
ref with some pre-defined keys.


=head1 PUBLIC METHODS

This module has a C<new()> constructor, which should only be called by
one of the C<POCOCM>'s modules.

The other public methods are the following accessors:

=over 4

=item * request()

The event sent to POCOCM.


=item * params()

The params of the event to POCOCM, as sent by client.


=item * status()

The status of the request. True for success, False in case of error.


=back

