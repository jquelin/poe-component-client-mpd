#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#

package POE::Component::Client::MPD;

use strict;
use warnings;

use POE qw[ Component::Client::TCP ];
use POE::Component::Client::MPD::Collection;
use POE::Component::Client::MPD::Connection;
use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors( qw[ _host _password _port  _version ] );


our $VERSION = '0.0.1';


sub spawn {
    my ($type, $args) = @_;

    my $collection = POE::Component::Client::MPD::Collection->new;
    #my $playlist   = POE::Component::Client::MPD::Playlist->new;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_start'    => \&_onpriv_start,
            '_send'     => \&_onpriv_send,
            '_got_data' => \&_onprot_got_data,
        },
        object_states => [
#             $self => [
#                 '_start', '_connected',
#                 '_got_data', '_got_mpd_version',
#                 ],
            $collection => {
                'coll:all_files' => '_all_files',
            },
        ],
    );

    return $session->ID;
}


sub _onpriv_start {
    my ($h, $args) = @_[HEAP, ARG0];

    # set up connection details.
    $args = {} unless defined $args;
    my %params = (
        host     => $ENV{MPD_HOST}     || 'localhost',
        port     => $ENV{MPD_PORT}     || '6600',
        password => $ENV{MPD_PASSWORD} || '',
        %$args,                        # overwrite previous defaults
        id       => $_[SESSION]->ID,   # required for connection
    );

    # set an alias (for easier communication) if requested.
    $_[KERNEL]->alias_set( $params{alias} ) if exists $params{alias};

    $h->{password} = delete $params{password};
    $h->{_socket}  = POE::Component::Client::MPD::Connection->spawn(\%params);
}

=pod

#
# _connected()
#
# received when the poe::component::client::tcp is (re-)connected to the
# mpd server.
#
sub _connected {
    my ($self, $k) = @_[OBJECT, KERNEL];
    $k->post($_[HEAP]{_socket}, 'send', 'status' );
    # send password information
}

sub _got_mpd_version {
    my ($self,$vers) = @_[OBJECT, ARG0];
    $self->_version($vers);
}



=cut



sub _onprot_got_data {
    my ($h, $data) = @_[HEAP, ARG0];
    my $args = shift @{ $h->{fifo} };
    $args->{data} = $data;
    print "mpd got data for " . $args->{from} . "\n";
    $_[KERNEL]->post( $args->{from}, 'mpd_result', $args );
}

#
# {
#   from    => $id,
#   state   => $state,
#   command => [ $cmd, ... ],
# }
#
# send data over tcp to mpd server. note that $data should not be newline
# terminated (it's handled via the poe::filter).
#
sub _onpriv_send {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    push @{ $h->{fifo} }, $args;
    $k->post( $h->{_socket}, 'send', @{ $args->{commands} } );
}





1;

__END__

=head1 NAME

POE::Component::Client::MPD - The great new POE::Component::Client::MPD!

=head1 VERSION

Version 0.01


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use POE::Component::Client::MPD;

    my $foo = POE::Component::Client::MPD->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 function1


=head2 function2


=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-poe-component-client-mpd at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-Client-MPD>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::Client::MPD

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-Client-MPD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-Client-MPD>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-Client-MPD>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-Client-MPD>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2007 Jerome Quelin, all rights reserved.

This program is released under the following license: gpl

=cut

