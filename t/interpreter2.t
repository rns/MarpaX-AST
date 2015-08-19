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
:default ::= action => ::array

:start ::= <boolean expression>
<boolean expression> ::=
       <variable>                                           bless => variable
     | '1'                                                  bless => constant
     | '0'                                                  bless => constant
     | ('(') <boolean expression> (')') action => ::first   bless => ::undef
    || ('not') <boolean expression>                         bless => not
    || <boolean expression> ('and') <boolean expression>    bless => and
    || <boolean expression> ('or') <boolean expression>     bless => or

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

sub bnf_to_ast {
    my ($bnf) = @_;
    my $recce = Marpa::R2::Scanless::R->new( { grammar => $grammar } );
    $recce->read( \$bnf );
    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        die "No parse for $bnf";
    }
    return ${$value_ref};
} ## end sub bnf_to_ast

my $demo_context = Context->new();
$demo_context->assign( x => 0 );
$demo_context->assign( y => 1 );
$demo_context->assign( z => 1 );
is $demo_context->show(), 'x=0 y=1 z=1', "context";

my $bnf  = q{true and x or y and not x};
my $ast1 = bnf_to_ast($bnf);
diag qq{Boolean 1 is "$bnf"} unless $prove;
is 'Value is ' . ($ast1->evaluate($demo_context) ? 'true' : 'false'),
    'Value is true', 'ast1 eval';
eq_or_diff MarpaX::AST::dumper($ast1), q{bless( [
  bless( [
    bless( [
      "true"
    ], 'Boolean_Expression::variable' ),
    bless( [
      "x"
    ], 'Boolean_Expression::variable' )
  ], 'Boolean_Expression::and' ),
  bless( [
    bless( [
      "y"
    ], 'Boolean_Expression::variable' ),
    bless( [
      bless( [
        "x"
      ], 'Boolean_Expression::variable' )
    ], 'Boolean_Expression::not' )
  ], 'Boolean_Expression::and' )
], 'Boolean_Expression::or' )
}, 'ast1 dump';


$bnf = 'not z';
my $ast2 = bnf_to_ast($bnf);
diag qq{Boolean 2 is "$bnf"} unless $prove;
is 'Value is ' . ($ast2->evaluate($demo_context) ? 'true' : 'false'), 'Value is false', 'ast2 eval';
eq_or_diff MarpaX::AST::dumper($ast2), q{bless( [
  bless( [
    "z"
  ], 'Boolean_Expression::variable' )
], 'Boolean_Expression::not' )
}, "ast2 dump";

my $ast3 = $ast1->replace( 'y', $ast2 );
diag q{Boolean 3 is Boolean 1, with "y" replaced by Boolean 2} unless $prove;
is 'Value is ' . ($ast3->evaluate($demo_context) ? 'true' : 'false'), , 'Value is false', 'ast3 eval';
eq_or_diff MarpaX::AST::dumper($ast3), q{bless( [
  bless( [
    bless( [
      "true"
    ], 'Boolean_Expression::variable' ),
    bless( [
      "x"
    ], 'Boolean_Expression::variable' )
  ], 'Boolean_Expression::and' ),
  bless( [
    bless( [
      bless( [
        "z"
      ], 'Boolean_Expression::variable' )
    ], 'Boolean_Expression::not' ),
    bless( [
      bless( [
        "x"
      ], 'Boolean_Expression::variable' )
    ], 'Boolean_Expression::not' )
  ], 'Boolean_Expression::and' )
], 'Boolean_Expression::or' )
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
    my ( $self, $context ) = @_;
    my ($value) = @{$self};
    return $value;
}

sub copy {
    my ($self)  = @_;
    my ($value) = @{$self};
    return bless [$value], ref $self;
}

sub replace {
    my ($self) = @_;
    return $self->copy();
}

package Boolean_Expression::variable;

sub evaluate {
    my ( $self, $context ) = @_;
    my ($name) = @{$self};
    return 1 if $name eq 'true';
    return 0
        if $name eq 'false';
    my $value = $context->lookup($name);
    return $value;
} ## end sub evaluate

sub copy {
    my ($self) = @_;
    my ($name) = @{$self};
    return bless [$name], ref $self;
}

sub replace {
    my ( $self, $name_to_replace, $expression ) = @_;
    my ($my_name) = @{$self};
    return $expression->copy() if $my_name eq $name_to_replace;
    return $self->copy();
} ## end sub replace

package Boolean_Expression::not;

sub evaluate {
    my ( $self, $context ) = @_;
    my ($exp1) = @{$self};
    return !$exp1->evaluate($context);
}

sub copy {
    my ($self) = @_;
    return bless [ map { $_->copy() } @{$self} ], ref $self;
}

sub replace {
    my ( $self, $name, $expression ) = @_;
    return bless [ map { $_->replace( $name, $expression ) } @{$self} ],
        ref $self;
}

package Boolean_Expression::and;

sub evaluate {
    my ( $self, $context ) = @_;
    my ( $exp1, $exp2 )    = @{$self};
    return $exp1->evaluate($context) && $exp2->evaluate($context);
}

sub copy {
    my ($self) = @_;
    return bless [ map { $_->copy() } @{$self} ], ref $self;
}

sub replace {
    my ( $self, $name, $expression ) = @_;
    return bless [ map { $_->replace( $name, $expression ) } @{$self} ],
        ref $self;
}

package Boolean_Expression::or;

sub evaluate {
    my ( $self, $context ) = @_;
    my ( $exp1, $exp2 )    = @{$self};
    return $exp1->evaluate($context) || $exp2->evaluate($context);
}

sub copy {
    my ($self) = @_;
    return bless [ map { $_->copy() } @{$self} ], ref $self;
}

sub replace {
    my ( $self, $name, $expression ) = @_;
    return bless [ map { $_->replace( $name, $expression ) } @{$self} ],
        ref $self;
}

