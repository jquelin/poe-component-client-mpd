#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

package POE::Component::Client::MPD::Item::Playlist;

use strict;
use warnings;

use base qw[ Class::Accessor::Fast POE::Component::Client::MPD::Item ];
__PACKAGE__->mk_accessors( qw[ playlist ] );

#our ($VERSION) = '$Rev: 5645 $' =~ /(\d+)/;

1;

__END__

=head1 NAME

POE::Component::Client::MPD::Item::Playlist - a playlist object


=head1 SYNOPSIS

    print $item->playlist . "\n";


=head1 DESCRIPTION

C<POCOCM::Item::Playlist> is more a placeholder for a hash ref with one
pre-defined key, namely the playlist name.


=head1 PUBLIC METHODS

This module only has a C<new()> constructor, which should only be called by
C<POCOCM::Item>'s constructor.

The only other public method is an accessor: playlist().


=head1 AUTHOR

Jerome Quelin, C<< <jquelin at cpan.org> >>


=head1 COPYRIGHT & LICENSE

Copyright (c) 2007 Jerome Quelin, all rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
