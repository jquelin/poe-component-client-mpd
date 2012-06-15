
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "File::Find" => 0,
    "File::Temp" => 0,
    "Module::Build" => "0.3601",
    "Test::More" => "0.88"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "full-blown poe-aware mpd client library",
  "dist_author" => [
    "Jerome Quelin"
  ],
  "dist_name" => "POE-Component-Client-MPD",
  "dist_version" => "1.121670",
  "license" => "perl",
  "module_name" => "POE::Component::Client::MPD",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Audio::MPD::Common::Item" => 0,
    "Audio::MPD::Common::Stats" => 0,
    "Audio::MPD::Common::Status" => 0,
    "Carp" => 0,
    "Moose" => "0.92",
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::Has::Sugar" => 0,
    "MooseX::POE" => 0,
    "MooseX::SemiAffordanceAccessor" => 0,
    "MooseX::Types::Moose" => 0,
    "POE" => 0,
    "POE::Component::Client::TCP" => 0,
    "Readonly" => 0,
    "Sub::Exporter" => 0,
    "Test::Corpus::Audio::MPD" => "1.120990",
    "perl" => "5.010",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
