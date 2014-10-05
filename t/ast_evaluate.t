#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use_ok 'MarpaX::AST';

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
my $ast = ${ $g->parse( \$input ) };

sub ast_evaluate{
    my ($ast) = @_;
    if (@$ast == 4){
        my ($e1, $op, $e2) = @$ast[1..3];
        if    ($op eq '+'){ ast_evaluate($e1) + ast_evaluate($e2) }
        elsif ($op eq '-'){ ast_evaluate($e1) - ast_evaluate($e2) }
        elsif ($op eq '*'){ ast_evaluate($e1) * ast_evaluate($e2) }
        elsif ($op eq '/'){ ast_evaluate($e1) / ast_evaluate($e2) }
        elsif ($op eq '**'){ ast_evaluate($e1) ** ast_evaluate($e2) }
    }
    else{
        return $ast->[1]->[1];
    }
}

say "$input=", ast_evaluate($ast);

done_testing;
