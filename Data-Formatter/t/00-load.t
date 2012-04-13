#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Data::Formatter' ) || print "Bail out!\n";
}

diag( "Testing Data::Formatter $Data::Formatter::VERSION, Perl $], $^X" );
