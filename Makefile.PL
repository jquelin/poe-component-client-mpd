#!perl
#
# This file is part of POE::Component::Client::MPD.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

require 5.8.0;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'POE::Component::Client::MPD',
    AUTHOR              => 'Jerome Quelin <jquelin@cpan.org>',
    VERSION_FROM        => 'lib/POE/Component/Client/MPD.pm',
    ABSTRACT_FROM       => 'lib/POE/Component/Client/MPD.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Audio::MPD::Common' => 0,
        'Class::Accessor'    => 0,
        'List::MoreUtils'    => 0,
        'POE'                => 0,
        'Readonly'           => 0,
        'Test::More'         => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => [
		'POE-Component-Client-MPD-*', 'MANIFEST.bak',
		map { ( '*/' x $_ ) . '*~' } 0..6
	] },
);
