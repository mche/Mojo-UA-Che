use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Mojo::UA::Che',
    AUTHOR           => q{Михаил Че (Mikhail Che) <mche[-at-]cpan.org>},
    VERSION_FROM     => 'lib/Mojo/UA/Che.pm',
    ABSTRACT_FROM    => 'lib/Mojo/UA/Che.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Mojo-UA-Che-*' },
);
