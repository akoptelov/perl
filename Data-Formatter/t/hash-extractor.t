#!perl -T

use strict;
use warnings;
use constant NUM => 10;
use constant STR => 'a string';
use Data::Formatter;
use Test::More tests => 2;

my $f1 = Data::Formatter->new({a => 'bar', b => 'baz', c => sub { $_->{baz} }});

my %hash = (bar => NUM, baz => STR);

is($f1->sprintf(\%hash, '%a$d %b$s %c$s'), sprintf("%d %s %s", NUM, STR, STR), '%HASH data');


SKIP: {
    eval "use Class::Struct;";
    skip 'Class::Struct is required for object formatting test', 1 if $@;

    my $f2 = Data::Formatter->new({a => 'bar', b => 'baz', c => sub { $_->baz() }});

    struct(Foo => {bar => '$', baz => '$'});
    my $d = Foo->new();
    $d->bar(NUM);
    $d->baz(STR);

    is($f2->sprintf($d, '%a$d %b$s %c$s'), sprintf("%d %s %s", NUM, STR, STR), 'Class data');
}
