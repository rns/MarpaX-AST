#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use_ok 'MarpaX::AST';

my $parser_module_dir;
BEGIN{
    $parser_module_dir = '../MarpaX-Languages-Lua-Parser/';
    $parser_module_dir = qq{../$parser_module_dir}
        unless $ENV{HARNESS_ACTIVE};
}

use lib qq{$parser_module_dir/lib};

use_ok 'MarpaX::Languages::Lua::Parser';

my $p = MarpaX::Languages::Lua::Parser->new(
    input_file_name => qq{$parser_module_dir/lua.sources/bisect.lua} );

my $ast = $p->process;

$ast = MarpaX::AST->new( ${ $ast } );

$ast = $ast->distill({
    root => 'root',
    skip => [
        'chunk', 'stat list', 'stat item',
        'optional colon name element',
        'optional parlist',
        'optional explist', 'exp',
        'optional laststat'
    ],
});

say $ast->sprint;

done_testing();
