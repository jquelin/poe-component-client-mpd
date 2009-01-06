#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007-2008 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;
use Module::Build;

my %requires = (
    'perl'                        => '5.010',
    'Audio::MPD::Common'          => '0.1.4',
    'Carp'                        => 0,
    'Class::Accessor::Fast'       => 0,
    'Exporter'                    => 0,
    'POE'                         => 0,
    'POE::Component::Client::TCP' => 0,
    'Readonly'                    => 0,
);
my %build_requires = (
    %requires,
    'FindBin'    => 0,
    'Test::More' => 0,
);
my %recommends = (
    'Test::Pod'           => 0,
    'Test::Pod::Coverage' => 0,
);

my $builder = Module::Build->new (
    module_name       => 'POE::Component::Client::MPD',
    dist_author       => 'Jerome Quelin <jquelin@cpan.org>',
    license           => 'perl',
    dist_version_from => 'lib/POE/Component/Client/MPD.pm',
    script_files      => [ ],
    build_requires    => \%build_requires,
    requires          => \%requires,
    recommends        => \%recommends,
    add_to_cleanup    => [
        'POE-Component-Client-MPD-*', 'MANIFEST.bak',
        map { ( '*/' x $_ ) . '*~' } 0..6 ],
);

$builder->create_build_script();
