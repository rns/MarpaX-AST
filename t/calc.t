#!/usr/bin/perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

require MarpaX::AST;
require MarpaX::AST::Visitor;
require MarpaX::AST::Interpreter;
require MarpaX::AST::Dispatching_Interpreter;

my $dumper = \&MarpaX::AST::dumper;

#
# Unambiguous grammar to parse arithmetic expressions
#
my $g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1

    Expr ::=
          Number
        | ('(') Expr (')')  assoc => group
       || Expr '**' Expr    assoc => right
       || Expr '*' Expr     # left associativity by default
        | Expr '/' Expr
       || Expr '+' Expr
        | Expr '-' Expr

    Number ~ [\d]+

:discard ~ whitespace
whitespace ~ [\s]+

END_OF_SOURCE
} );

my @inputs = qw{ 4+5*6+8 (4+5)*(6+8) (4+5)*(6+8)**2/5 };

for my $input (@inputs){
    my $ast = MarpaX::AST->new( ${ $g->parse( \$input ) } );
    is ast_eval_AoA($ast), eval $input, "$input, ast_eval_AoA()";
}

# todo: find a place for this -- node_print for distill? also use ->text()
=pod
$ast->walk({
    visit => sub {
        my ($ast, $context) = @_;
        my ($node_id, @children) = @$ast;
        say ' ' x $context->{depth}, $node_id, $ast->is_literal ? ": '" . $ast->text . "'" : '';
    }
});
=cut

#
# evaluate ast as array of arrays with 0th element being the node id
#
sub ast_eval_AoA{
    my ($ast) = @_;
    # binop
    if (@$ast == 4){
        my ($e1, $op, $e2) = @$ast[1..3];
        if    ($op eq '+'){ ast_eval_AoA($e1) + ast_eval_AoA($e2) }
        elsif ($op eq '-'){ ast_eval_AoA($e1) - ast_eval_AoA($e2) }
        elsif ($op eq '*'){ ast_eval_AoA($e1) * ast_eval_AoA($e2) }
        elsif ($op eq '/'){ ast_eval_AoA($e1) / ast_eval_AoA($e2) }
        elsif ($op eq '**'){ ast_eval_AoA($e1) ** ast_eval_AoA($e2) }
    }
    # number
    elsif (@$ast == 2 and $ast->[1]->[0] eq 'Number'){
        return $ast->[1]->[1];
    }
    # parenthesized
    elsif (@$ast == 2){
        ast_eval_AoA($ast->[1]);
    }
    else{
        die "Unknown node: " . $ast->sprint;
    }
}

#
# evaluate ast using MarpaX::AST methods
#
sub ast_eval{
    my ($ast) = @_;
    # number
    if ($ast->id eq 'Expr' and $ast->first_child->id eq 'Number'){
        return $ast->first_grandchild;
    }
    # parenthesized
    elsif ($ast->children_count == 1 and $ast->first_child->id eq 'Expr'){
        ast_eval($ast->first_child);
    }
    # binop
    elsif ($ast->children_count == 3) {
        my ($e1, $op, $e2) = @{ $ast->children() };
        if    ($op eq '+'){ ast_eval($e1) + ast_eval($e2) }
        elsif ($op eq '-'){ ast_eval($e1) - ast_eval($e2) }
        elsif ($op eq '*'){ ast_eval($e1) * ast_eval($e2) }
        elsif ($op eq '/'){ ast_eval($e1) / ast_eval($e2) }
        elsif ($op eq '**'){ ast_eval($e1) ** ast_eval($e2) }
    }
    else{
        die "Unknown node: " . $ast->sprint;
    }
}

for my $input (@inputs){
    my $ast = MarpaX::AST->new( ${ $g->parse( \$input ) } );
    is ast_eval($ast), eval $input, "$input, ast_eval()";
}

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

sub visit_par{
    my ($v, $ast) = @_;
    $v->visit( $ast->first_child )
}

package main;

$g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1

    # as we dispatch based on node id -- methods are defined as visit_$node_id()
    # or interpreter's packages, we need to add name's, but may omit all literals
    Expr ::=
          Number                              name => 'num'
        | ('(') Expr (')')  assoc => group    name => 'par'
       || Expr ('**') Expr  assoc => right    name => 'pow'
       || Expr ('*') Expr                     name => 'mul'
        | Expr ('/') Expr                     name => 'div'
       || Expr ('+') Expr                     name => 'add'
        | Expr ('-') Expr                     name => 'sub'

    Number ~ [\d]+

:discard ~ whitespace
whitespace ~ [\s]+

END_OF_SOURCE
} );

for my $input (@inputs){
    my $ast = MarpaX::AST->new( ${ $g->parse( \$input ) } );
#    warn $ast->sprint;
    my $v = My::Visitor->new();
    is $v->visit($ast), eval $input, "$input, Visitor pattern";
}

#
# evaluate ast using Interpreter pattern (context-free: no variables in the grammar)
#

sub add::cmpt {
    my (undef, $interp, $ast) = @_;
    $interp->cmpt($ast->first_child) + $interp->cmpt($ast->last_child)
}

sub sub::cmpt { $_[1]->cmpt($_[2]->first_child) - $_[1]->cmpt($_[2]->last_child) }
sub mul::cmpt { $_[1]->cmpt($_[2]->first_child) * $_[1]->cmpt($_[2]->last_child) }
sub div::cmpt { $_[1]->cmpt($_[2]->first_child) / $_[1]->cmpt($_[2]->last_child) }
sub pow::cmpt { $_[1]->cmpt($_[2]->first_child) ** $_[1]->cmpt($_[2]->last_child) }

sub num::cmpt { $_[2]->first_child->text }
sub par::cmpt { $_[1]->cmpt($_[2]->first_child) }

# inheritance-based interpreters
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

package My::Interpreter::par;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate;
}

# set up an interpreter with single class for all binary operations
package My::Simpler::Interpreter::num;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->text
}

package My::Simpler::Interpreter::binop;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    my $op = $ast->id;
    if    ($op eq 'add') { $ast->first_child->evaluate + $ast->last_child->evaluate }
    elsif ($op eq 'sub') { $ast->first_child->evaluate - $ast->last_child->evaluate }
    elsif ($op eq 'mul') { $ast->first_child->evaluate * $ast->last_child->evaluate }
    elsif ($op eq 'div') { $ast->first_child->evaluate / $ast->last_child->evaluate }
    elsif ($op eq 'pow') { $ast->first_child->evaluate ** $ast->last_child->evaluate }
}

package My::Simpler::Interpreter::par;
use parent 'MarpaX::AST';

sub evaluate {
    my ($ast) = @_;
    $ast->first_child->evaluate;
}

package main;

for my $input (@inputs){
    my $ast = MarpaX::AST->new( ${ $g->parse( \$input ) } );
#    warn $ast->sprint;

    # create interpreter with default options:
    # node_id packages in main::*, context initialized to { }
    my $i = MarpaX::AST::Dispatching_Interpreter->new();

#    warn MarpaX::AST::dumper( $i->ast );
    # dispatch-based
    is $i->cmpt($ast), # context-free interpreting :)
        eval $input, "$input, dispatching interpreter (context-free)";

    # special class for each binary op
    my $i1 = MarpaX::AST::Interpreter->new(
        $ast, { namespace => 'My::Interpreter', skip => [qw{Number}] });

    is $i1->ast->evaluate, # context-free interpreting :)
        eval $input, "$input, inheritance-based interpreter (context-free)";

    # single class for all binary ops
    my $i2 = MarpaX::AST::Interpreter->new(
        $ast, { namespace => 'My::Simpler::Interpreter', skip => [qw{Number}],
            'My::Simpler::Interpreter::binop' => [qw{ add sub mul pow div }] });

    is $i2->ast->evaluate, # context-free interpreting :)
        eval $input, "$input, simpler inheritance-based interpreter (context-free)";
}

#
# evaluate ast using Interpreter pattern (in context, with variables in the grammar)
#
$g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

:default ::= action => [ name, value ]
lexeme default = action => [ name, value ] latm => 1

    Expr ::=
          # expression is evaluated with variables substitution
          Var                                 name => 'var'
       || Number                              name => 'num'
       || ('(') Expr (')')  assoc => group    name => 'par'
       || Expr ('**') Expr  assoc => right    name => 'pow'
       || Expr ('*') Expr                     name => 'mul'
        | Expr ('/') Expr                     name => 'div'
       || Expr ('+') Expr                     name => 'add'
        | Expr ('-') Expr                     name => 'sub'

    Number ~ [\d]+
    Var    ~ [a-z]+

:discard ~ whitespace
whitespace ~ [\s]+

END_OF_SOURCE
} );

#
# add a method to Visitor namespace to test visitor in context
# with variables in the grammar
#
sub My::Visitor::visit_var{
    my ($visitor, $ast) = @_;
    # lookup the variable value by its name in the context
    $visitor->ctx->{ $ast->first_child->text };
}

# dispatch-based interpreter (using AUTOLOAD)
package My::Expr::add;

# use custom namespace for interpreter; we could just add
# a method for variable lookup as with My::Visitor above

sub cmpt {
    my (undef, $interp, $ast) = @_; # we use just the namespace, so no $self
    $interp->cmpt($ast->first_child) + $interp->cmpt($ast->last_child)
}

sub My::Expr::sub::cmpt { $_[1]->cmpt($_[2]->first_child) - $_[1]->cmpt($_[2]->last_child) }
sub My::Expr::mul::cmpt { $_[1]->cmpt($_[2]->first_child) * $_[1]->cmpt($_[2]->last_child) }
sub My::Expr::div::cmpt { $_[1]->cmpt($_[2]->first_child) / $_[1]->cmpt($_[2]->last_child) }
sub My::Expr::pow::cmpt { $_[1]->cmpt($_[2]->first_child) ** $_[1]->cmpt($_[2]->last_child) }

sub My::Expr::num::cmpt { $_[2]->first_child->text }
sub My::Expr::par::cmpt { $_[1]->cmpt($_[2]->first_child) }

# lookup the variable value by its name in the context
sub My::Expr::var::cmpt{ $_[1]->ctx->{ $_[2]->first_child->text } }

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

@inputs = qw{   x-1+y*z    (x+y)*(a+b)    (a+b)*(x+y)**2/5   };

my $context = { a => 42, b => 84, x => 1, y => 2, z => 3 };

for my $input (@inputs){

    # substitute variables to produce expected value
    my $subst = $input;
    $subst =~ s/$_/$context->{$_}/g for keys %{ $context };

    my $ast = MarpaX::AST->new( ${ $g->parse( \$input ) } );

    # contextual interpreting
    my $i = MarpaX::AST::Dispatching_Interpreter->new(
        { namespace => 'My::Expr', context => $context } );
    is $i->cmpt($ast), eval $subst, "$input, Interpreter pattern (in context)";

    # contextual visiting
    my $v = My::Visitor->new( { context => $context } );
    is $v->visit($ast), eval $subst, "$input, Visitor pattern (in context)";
}

done_testing();
