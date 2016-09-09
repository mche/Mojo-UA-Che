#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Mojo::UA::Che' ) || print "Bail out!\n";
}

diag( "Testing Mojo::UA::Che $Mojo::UA::Che::VERSION, Perl $], $^X" );
