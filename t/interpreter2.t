#!env perl

# Copyright 2015 Ruslan Shvedov

# GoF Interpreter (Example 2) based on https://gist.github.com/jeffreykegler/5121769

use 5.010;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use Marpa::R2;

use_ok 'MarpaX::AST';
use_ok 'MarpaX::AST::Interpreter';

my $prove = $ENV{HARNESS_ACTIVE};

# Note Go4 ignores precedence
my $rules = <<'END_OF_GRAMMAR';
:default ::= action => [ name, value ]
lexeme default = action => [ value ] latm => 1

:start ::= <boolean expression>
<boolean expression> ::=
       <variable>                                           name => 'variable'
     | '1'                                                  name => 'constant'
     | '0'                                                  name => 'constant'
     | ('(') <boolean expression> (')')                     name => 'parenthesized'
    || ('not') <boolean expression>                         name => 'not'
    || <boolean expression> ('and') <boolean expression>    name => 'and'
    || <boolean expression> ('or') <boolean expression>     name => 'or'

<variable> ~ [[:alpha:]] <zero or more word characters>
<zero or more word characters> ~ [\w]*

:discard ~ whitespace
whitespace ~ [\s]+
END_OF_GRAMMAR

my $grammar = Marpa::R2::Scanless::G->new(
    {   bless_package => 'Boolean_Expression',
        source        => \$rules,
    }
);

sub expr_to_ast {
    my ($expr) = @_;
    my $recce = Marpa::R2::Scanless::R->new( { grammar => $grammar } );
    $recce->read( \$expr );
    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        die "No parse for $expr";
    }
    return MarpaX::AST->new( ${$value_ref} );
}

my $demo_context = Context->new();
$demo_context->assign( x => 0 );
$demo_context->assign( y => 1 );
$demo_context->assign( z => 1 );
is $demo_context->show(), 'x=0 y=1 z=1', "context";

my $expr  = q{true and x or y and not x};
my $ast1 = expr_to_ast($expr);
# warn "# ast1:\n", $ast1->sprint;
diag qq{Boolean 1 is "$expr"} unless $prove;

my $interp = MarpaX::AST::Interpreter->new({
    namespace => 'Boolean_Expression',
    context => $demo_context,
});

is 'Value is ' . ($interp->evaluate($ast1) ? 'true' : 'false'),
    'Value is true', 'ast1 eval';
eq_or_diff $ast1->sprint, q{ or
   and
     variable
       true
     variable
       x
   and
     variable
       y
     not
       variable
         x
}, 'ast1 dump';


$expr = 'not z';
my $ast2 = expr_to_ast($expr);
# warn "# ast2:\n", $ast2->sprint;
diag qq{Boolean 2 is "$expr"} unless $prove;
is 'Value is ' . ($interp->evaluate($ast2) ? 'true' : 'false'), 'Value is false', 'ast2 eval';
eq_or_diff $ast2->sprint, q{ not
   variable
     z
}, "ast2 dump";

my $ast3 = $interp->replace( $ast1, 'y', $ast2 );
# warn "# ast3:\n", $ast3->sprint;
diag q{Boolean 3 is Boolean 1, with "y" replaced by Boolean 2} unless $prove;
is 'Value is ' . ($interp->evaluate($ast3) ? 'true' : 'false'), , 'Value is false', 'ast3 eval';
eq_or_diff $ast3->sprint, q{ or
   and
     variable
       true
     variable
       x
   and
     not
       variable
         z
     not
       variable
         x
}, "ast3 dump";

done_testing();

package Context;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub assign {
    my ( $self, $name, $value ) = @_;
    return $self->{$name} = $value;
}

sub lookup {
    my ( $self, $name ) = @_;
    my $value = $self->{$name};
    die qq{Attempt to read undefined boolean variable named "$name"}
        if not defined $value;
    return $value;
} ## end sub lookup

sub show {
    my ($self) = @_;
    return join q{ }, map { join q{=}, $_, $self->{$_} } sort keys %{$self};
}

package Boolean_Expression::constant;

sub evaluate {
    my ( undef, $interp, $ast ) = @_;
    my ($value) = $ast->first_child->id;
    return $value;
}

sub copy {
    my ( undef, $interp, $ast )  = @_;
    return MarpaX::AST->new([ $ast->id, [ $ast->first_child->id ] ]);
}

sub replace {
    my ( undef, $interp, $ast )  = @_;
    return $interp->copy($ast);
}

package Boolean_Expression::variable;

sub evaluate {
    my ( undef, $interp, $ast ) = @_;
    my ($name) = $ast->first_child->id;
    return 1 if $name eq 'true';
    return 0 if $name eq 'false';
    my $value = $interp->context->lookup($name);
    return $value;
} ## end sub evaluate

sub copy {
    my ( undef, $interp, $ast) = @_;
    return MarpaX::AST->new([ $ast->id, [ $ast->first_child->id ] ]);
}

sub replace {
    my ( undef, $interp, $ast, $name_to_replace, $expression ) = @_;
    my ($my_name) = $ast->first_child->id;
    return $interp->copy($expression) if $my_name eq $name_to_replace;
    return $interp->copy($ast);
} ## end sub replace

package Boolean_Expression::not;

sub evaluate {
    my ( undef, $interp, $ast ) = @_;
    return !$interp->evaluate( $ast->first_child );
}

sub copy {
    my (undef, $interp, $ast) = @_;
    return MarpaX::AST->new([
        $ast->id,
        map { $interp->copy($_) } @{$ast->children}
    ]);
}

sub replace {
    my ( undef, $interp, $ast, $name, $expression ) = @_;
    return MarpaX::AST->new([
        $ast->id,
        map { $interp->replace( $_, $name, $expression ) } @{$ast->children}
    ]);
}

package Boolean_Expression::and;

sub evaluate {
    my ( undef, $interp, $ast ) = @_;
    $interp->evaluate($ast->first_child) && $interp->evaluate($ast->last_child);
}

sub copy {
    my ( undef, $interp, $ast ) = @_;
    return MarpaX::AST->new([ $ast->id, map { $interp->copy($_) } @{$ast->children} ]);
}

sub replace {
    my ( undef, $interp, $ast, $name, $expression ) = @_;
    return MarpaX::AST->new([
        $ast->id,
        map { $interp->replace( $_, $name, $expression ) } @{$ast->children}
    ]);
}

package Boolean_Expression::or;

sub evaluate {
    my ( undef, $interp, $ast ) = @_;
    return $interp->evaluate($ast->first_child) || $interp->evaluate($ast->last_child);
}

sub copy {
    my (undef, $interp, $ast) = @_;
    return MarpaX::AST->new([ $ast->id, map { $interp->copy($_) } @{$ast->children} ]);
}

sub replace {
    my ( undef, $interp, $ast, $name, $expression ) = @_;
    return MarpaX::AST->new( [
        $ast->id,
        map { $interp->replace( $_, $name, $expression ) } @{$ast->children}
    ] );
}

