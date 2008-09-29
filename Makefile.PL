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
        'Rose::DBx::Garden' => 0.15,
        'Rose::DB::Object'  => 0.770,
        'Rose::DBx::Object::MoreHelpers' => 0.02,
        'Rose::DBx::AutoReconnect'       => 0,
        'Rose::HTMLx::Form::Related'     => 0.07,
        'CatalystX::CRUD::YUI' => 0.004,
        'Catalyst'          => 5.7,
        'Catalyst::Plugin::ConfigLoader' => 0,
        'Catalyst::Plugin::Static::Simple' => 0,
        'Data::Dump'        => 0,
        'Tree::Simple'      => 0,
        'Tree::Simple::Visitor::ToNestedHash' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Rose-DBx-Garden-Catalyst-* t/lib/MyRDGC/lib/MyRDBO*
                                       t/lib/MyRDGC/lib/MyRDGC/Controller/CRUD*
                                       t/lib/MyRDGC/lib/MyRDGC/Model/*
                                       t/lib/MyRDGC/lib/MyRDGC/Base
                                       t/lib/MyRDGC/lib/MyRDGC/View/*
                                       t/lib/MyRDGC/root/crud 
                                       t/lib/MyRDGC/root/rdgc
                                       t/lib/MyRDGC/root/static

                            ' },
);
