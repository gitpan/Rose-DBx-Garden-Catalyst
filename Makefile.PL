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
        'Rose::DBx::Garden' => 0.14,
        'Rose::DB::Object'  => 0.770,
        'Catalyst'          => 5.7,
        'JSON::XS'          => 2.00,
        'Data::Dump'        => 0,
        'Tree::Simple'      => 0,
        'Tree::Simple::Visitor::ToNestedHash' => 0,
        'Path::Class'       => 0,
        'Template'          => 0,
        'Text::Autoformat'   => 0,
        'Catalyst::View::TT' => 0,
        'CatalystX::CRUD'                     => 0.28,
        'CatalystX::CRUD::Model::RDBO'        => 0.12,
        'CatalystX::CRUD::Controller::RHTMLO' => 0.13,
        'CatalystX::CRUD::View::Excel'        => 0.05,
        'Scalar::Util'     => 0,
        'Class::C3'        => 0,


    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Rose-DBx-Garden-Catalyst-*' },
);
