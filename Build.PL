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
use Module::Build;

my $builder = Module::Build->new (
    module_name         => 'POE::Component::Client::MPD',
    dist_author         => 'Jerome Quelin <jquelin@cpan.org>',
    license             => 'perl',
    dist_version_from   => 'lib/POE/Component/Client/MPD.pm',
    add_to_cleanup => [ 'POE-Component-Client-MPD-*',
                        map { ( '*/' x $_ ) . '*~' } 0..6 ],
    script_files => [ ],
    build_requires => {
        'Test::More'  => 0,
    },
    requires => {
        'Class::Accessor' => 0,
        'List::MoreUtils' => 0,
        'POE'             => 0,
        'Readonly'        => 0,
        'perl'            => '5.8.0',
    },
);

$builder->create_build_script();
