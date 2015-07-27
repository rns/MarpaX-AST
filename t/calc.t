#!/usr/bin/perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use_ok 'MarpaX::AST';

my $dumper = \&MarpaX::AST::dumper;

#
# Unambiguous grammar to parse expressions on numbers
#
my $g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1

    Expr ::=
          Number
        | ('(') Expr (')')  assoc => group
       || Expr '**' Expr    assoc => right
       || Expr '*' Expr     # left associativity is by default
        | Expr '/' Expr
       || Expr '+' Expr
        | Expr '-' Expr

    Number ~ [\d]+

:discard ~ whitespace
whitespace ~ [\s]+

END_OF_SOURCE
} );

my $input = '4+5*6+8';

my $ast = MarpaX::AST->new( ${ $g->parse( \$input ) } );

my $result;
my $op;

$ast->walk({
    visit => sub {
        my ($ast, $context) = @_;
        my ($node_id, @children) = @$ast;
        say ' ' x $context->{depth}, $node_id, $ast->is_literal ? qq{: $children[0]} : '';
    }
});

sub ast_eval_AoA{
    my ($ast) = @_;
    if (@$ast == 4){
        my ($e1, $op, $e2) = @$ast[1..3];
        if    ($op eq '+'){ ast_eval_AoA($e1) + ast_eval_AoA($e2) }
        elsif ($op eq '-'){ ast_eval_AoA($e1) - ast_eval_AoA($e2) }
        elsif ($op eq '*'){ ast_eval_AoA($e1) * ast_eval_AoA($e2) }
        elsif ($op eq '/'){ ast_eval_AoA($e1) / ast_eval_AoA($e2) }
        elsif ($op eq '**'){ ast_eval_AoA($e1) ** ast_eval_AoA($e2) }
    }
    else{
        return $ast->[1]->[1];
    }
}

sub ast_eval{
    my ($ast) = @_;
    if ($ast->id eq 'Expr' and $ast->first_child->id eq 'Number'){
        return $ast->first_child->first_child;
    }
    else {
        my ($e1, $op, $e2) = @{ $ast->children() };
        if    ($op eq '+'){ ast_eval($e1) + ast_eval($e2) }
        elsif ($op eq '-'){ ast_eval($e1) - ast_eval($e2) }
        elsif ($op eq '*'){ ast_eval($e1) * ast_eval($e2) }
        elsif ($op eq '/'){ ast_eval($e1) / ast_eval($e2) }
        elsif ($op eq '**'){ ast_eval($e1) ** ast_eval($e2) }
    }
}

is ast_eval_AoA($ast), eval $input, "$input, ast_eval_AoA()";
is ast_eval($ast), eval $input, "$input, ast_eval()";

done_testing();
