#!env perl
# Copyright 2014 Ruslan Shvedov

use 5.010;
use warnings;
use strict;

use Test::More;

if (not eval { require MarpaX::AST; 1; }) {
    Test::More::diag($@);
    Test::More::BAIL_OUT('Could not load MarpaX::AST');
}

use_ok 'MarpaX::AST';

done_testing();
