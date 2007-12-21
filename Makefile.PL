use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Rose::DBx::Garden::Catalyst',
    AUTHOR              => 'Peter Karman <karman@cpan.org>',
    VERSION_FROM        => 'lib/Rose/DBx/Garden/Catalyst.pm',
    ABSTRACT_FROM       => 'lib/Rose/DBx/Garden/Catalyst.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Rose::DBx::Garden' => 0.05,
        'Catalyst'          => 5.7,
        'YAML::Syck'        => 0,
        'JSON'              => 2.00,
        'Data::Dump'        => 0,
        'Tree::Simple'      => 0,
        'Tree::Simple::Visitor::ToNestedHash' => 0,
        'Path::Class'       => 0,
        'Template'          => 0,
        'Catalyst::View::TT' => 0,
        'CatalystX::CRUD' => 0.12,
        'CatalystX::CRUD::Model::RDBO' => 0.06,
        'CatalystX::CRUD::Controller::RHTMLO' => 0.08,
        'Scalar::Util'     => 0,


    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Rose-DBx-Garden-Catalyst-*' },
);
