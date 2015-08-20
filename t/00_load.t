#!env perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use warnings;
use strict;

use Test::More;

if (not eval { require MarpaX::AST; 1; }) {
    diag($@);
    BAIL_OUT('Could not load MarpaX::AST');
}
else{
    ok 1
}

done_testing();
