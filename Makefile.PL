#!perl
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
		'Class::Accessor' => 0,
		'POE'             => 0,
		'Readonly'        => 0,
        'Test::More'      => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => [
		'POE-Component-Client-MPD-*',
		map { ( '*/' x $_ ) . '*~' } 0..6
		] },
);
