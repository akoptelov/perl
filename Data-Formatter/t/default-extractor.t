#!perl -T

use strict;
use warnings;
use Class::Struct;
use constant NUM => 10;
use constant STR => 'a string';
use Data::Formatter;
use Test::More tests => 2;

my $f = Data::Formatter->new();

my %hash = (bar => NUM, baz => STR);

is($f->sprintf(\%hash, '%bar$d %baz$s'), sprintf("%d %s", NUM, STR), '%HASH data');

struct Foo => {bar => '$', baz => '$'};
my $d = Foo->new();
$d->bar(NUM);
$d->baz(STR);

is($f->sprintf($d, '%bar$d %baz$s'), sprintf("%d %s", NUM, STR), 'Class data');
