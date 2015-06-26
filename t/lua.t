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

my %skip_always = map { $_ => 1 } (
    'chunk', 'stat list', 'stat item',
    'optional colon name element',
    'optional parlist',
    'optional explist', 'exp',
    'optional laststat'
);

$ast = $ast->distill({
    root => 'root',
    skip => sub {
        my ($ast, $ctx) = @_;
        my ($node_id) = @$ast;
        if ( $node_id eq 'exp' ){
            if (    $ctx->{parent}->id eq 'stat'
                and $ctx->{parent}->first_child->id eq 'keyword if'){
#                say qq{#parent:\n}, $ctx->{parent}->sprint, qq{\n#of\n}, $ast->sprint;
                return 0;
            }
            else{
                return 1;
            }
        }
        return exists $skip_always{ $node_id }
    }
});

say $ast->sprint;


done_testing();
