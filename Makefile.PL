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
        'Rose::DBx::Object::MoreHelpers' => 0.01,
        'Rose::HTMLx::Form::Related'     => 0.01,
        'CatalystX::CRUD::YUI' => 0,
        'Catalyst'          => 5.7,
        'JSON::XS'          => 2.00,
        'Data::Dump'        => 0,
        'Tree::Simple'      => 0,
        'Tree::Simple::Visitor::ToNestedHash' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Rose-DBx-Garden-Catalyst-*' },
);
