#!perl
#

use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new (
	module_name         => 'POE::Component::Client::MPD',
	license             => 'gpl',
    dist_version_from   => 'lib/POE/Component/Client/MPD.pm',
    add_to_cleanup => [ 'POE-Component-Client-MPD-*',
                        '*~', '*/*~', '*/*/*~', '*/*/*/*~', '*/*/*/*/*~' ],
    script_files => [ ],
    build_requires => {
        'Test::More'  => 0,
    },
    requires => {
        'Audio::MPD' => '0.14.0',
        'POE'        => 0,
        'perl'       => '5.8.0',
    },
);

$builder->create_build_script();
