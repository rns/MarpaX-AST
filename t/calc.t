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

$ast->walk({
    visit => sub {
        my ($ast, $context) = @_;
        my ($node_id, @children) = @$ast;
        say ' ' x $context->{depth}, $node_id, $ast->is_literal ? qq{: $children[0]} : '';
    }
});

#
# evaluate ast as array of arrays with 0th element being the node id
#
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

is ast_eval_AoA($ast), eval $input, "$input, ast_eval_AoA()";

#
# evaluate ast using MarpaX::AST methods
#
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

is ast_eval($ast), eval $input, "$input, ast_eval()";

#
# evaluate ast using Visitor pattern ($v is for visitor)
#
package My::Visitor;

use parent 'MarpaX::AST::Visitor';

sub visit_num{
    my ($v, $ast) = @_;
    $ast->first_child->text
}

sub visit_add{
    my ($v, $ast) = @_;
    $v->visit( $ast->first_child ) + $v->visit( $ast->last_child )
}

sub visit_sub{
    my ($v, $ast) = @_;
    $v->visit( $ast->first_child ) - $v->visit( $ast->last_child )
}

sub visit_mul{
    my ($v, $ast) = @_;
    $v->visit( $ast->first_child ) * $v->visit( $ast->last_child )
}

sub visit_div{
    my ($v, $ast) = @_;
    $v->visit( $ast->first_child ) / $v->visit( $ast->last_child )
}

sub visit_pow{
    my ($v, $ast) = @_;
    $v->visit( $ast->first_child ) ** $v->visit( $ast->last_child )
}

sub visit_parens{
    my ($v, $ast) = @_;
    $v->visit( $ast->first_child )
}

package main;

$g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1

    # as we dispatch based on node id -- methods are defined as visit_$node_id()
    # we need to add name's, but may omit all literals
    Expr ::=
          Number                              name => 'num'
        | ('(') Expr (')')  assoc => group    name => 'parens'
       || Expr ('**') Expr    assoc => right  name => 'pow'
       || Expr ('*') Expr                     name => 'mul'
        | Expr ('/') Expr                     name => 'div'
       || Expr ('+') Expr                     name => 'add'
        | Expr ('-') Expr                     name => 'sub'

    Number ~ [\d]+

:discard ~ whitespace
whitespace ~ [\s]+

END_OF_SOURCE
} );

my @inputs = qw{ 4+5*6+8 (4+5)*(6+8) (4+5)*(6+8)**12/5 };

for my $inp (@inputs){
    $ast = MarpaX::AST->new( ${ $g->parse( \$inp ) } );
#    warn $ast->sprint;
    my $v = My::Visitor->new();
    is $v->visit($ast), eval $inp, "$inp, Visitor pattern";
}

#
# evaluate ast using Interpreter pattern ($i is for interperter)
#
use_ok 'MarpaX::AST::Interpreter';

package My::Interpreter::num;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->text
}

package My::Interpreter::add;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate + $ast->last_child->evaluate;
}

package My::Interpreter::sub;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate - $ast->last_child->evaluate;
}

package My::Interpreter::mul;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate * $ast->last_child->evaluate;
}

package My::Interpreter::div;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate / $ast->last_child->evaluate;
}

package My::Interpreter::pow;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate ** $ast->last_child->evaluate;
}

package My::Interpreter::parens;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate;
}

package main;

for my $inp (@inputs){
    $ast = MarpaX::AST->new( ${ $g->parse( \$inp ) } );
#    warn $ast->sprint;
    my $i = MarpaX::AST::Interpreter->new( $ast, { skip => [qw{ Number }] } );
    warn MarpaX::AST::dumper( $i->ast );
    is $i->ast->evaluate, eval $inp, "$inp, Interpreter pattern";
}

done_testing();
