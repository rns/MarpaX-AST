#!env perl

# Copyright 2015 Ruslan Shvedov

# ambiguous English phrases
# based on: https://github.com/jeffreykegler/Marpa--R2/blob/master/cpan/t/sl_timelies.t

use 5.010;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use Marpa::R2;

use_ok 'MarpaX::AST';

my $grammar = Marpa::R2::Scanless::G->new({ source => \(<<'END_OF_SOURCE'),

:default     ::= action => [ name, value ]
lexeme default = action => [ name, value ]

S   ::= NP  VP  period

NP  ::= NN
    |   DT  NN
    |   NN  NNS

VP  ::= VBP NP
    |   VBP PP
    |   VBZ PP

PP  ::= IN  NP

period ~ '.'

:discard ~ whitespace
whitespace ~ [\s]+

DT  ~ 'a' | 'an'
NN  ~ 'arrow' | 'banana'
NNS ~ 'flies'
VBZ ~ 'flies'
NN  ~ 'fruit':i
VBP ~ 'fruit':i
IN  ~ 'like'
VBP ~ 'like'
NN  ~ 'time':i
VBP ~ 'time':i

END_OF_SOURCE
});

my $expected = <<'EOS';
(S
  (NP(NN Time))
  (VP(VBZ flies)
    (PP(IN like)
      (NP(DT an) (NN arrow))))
  (. .))
(S
  (NP(NN Time) (NNS flies))
  (VP(VBP like)
    (NP(DT an) (NN arrow)))
  (. .))
(S
  (NP(NN Fruit))
  (VP(VBZ flies)
    (PP(IN like)
      (NP(DT a) (NN banana))))
  (. .))
(S
  (NP(NN Fruit) (NNS flies))
  (VP(VBP like)
    (NP(DT a) (NN banana)))
  (. .))
EOS

my $paragraph = <<END_OF_PARAGRAPH;
Time flies like an arrow.
Fruit flies like a banana.
END_OF_PARAGRAPH

my @values = ();
for my $sentence (split /\n/, $paragraph){

    my $recce = Marpa::R2::Scanless::R->new( { grammar => $grammar  } );
    $recce->read( \$sentence );

    while ( defined( my $value_ref = $recce->value() ) ) {
        my $value = $value_ref ? ${$value_ref} : 'No parse';
        push @values, $value;
    }
}

#
# recursion
#
my @actual = map { ast_bracket ( MarpaX::AST->new( $_ ) ) } @values;

sub ast_bracket{
    my ($ast, $ctx) = @_;
#    warn $ast->sprint;
    state $structural = { map { $_ => undef } qw{ NP VP PP period } };
    state $level = 0;
    my $tag    = $ast->id;
    my $result = exists $structural->{$tag} ? ("\n" . ("  " x $level)) : '';
    $result .= '(';
    $level++;
    if ($ast->is_literal){
        $result .= $tag eq 'period' ? '. .' : $tag . ' ' . $ast->text;
    }
    else{
        $result .= $tag . join(' ', map { ast_bracket($_) } @{ $ast->children() } );
    }
    $result .= ')';
    $level--;
    return $result;
}

my $got = join ( "\n", @actual ) . "\n";
$got =~ s{\s+\n}{\n}gms;

eq_or_diff( $got, $expected, 'Ambiguous English sentences, recursion' );

# Visitor inheritance for custom options
package My::Visitor;

use parent 'MarpaX::AST::Visitor';

sub new{
    my ($class) = @_;
    return $class->SUPER::new( {
        visit_structural => [qw{ S NP VP PP period }],
        visit_literal => sub { $_[0]->is_literal }
    } );
}

sub visit_structural{
    my ($visitor, $ast, $context) = @_;
    my $level = $context->{level};
    return "\n" . ("  " x $context->{level}) . '(. .)' if $ast->id eq 'period';
    return ($ast->id eq 'S' ? '' : "\n") . ("  " x $level) .
        '(' .
        $ast->id . join(' ', map { $visitor->visit($_) } @{ $ast->children() } ) .
        ')';
}

sub visit_literal{
    my ($visitor, $ast) = @_;
    return '(' . $ast->id . ' ' . $ast->text . ')';
}

package main;

my $v = My::Visitor->new;

@actual = map { my $ast = MarpaX::AST->new($_); $v->visit($ast) } @values;

$got = join ( "\n", @actual ) . "\n";
$got =~ s{\s+\n}{\n}gms;

eq_or_diff( $got, $expected, 'Ambiguous English sentences, Visitor pattern' );

# Interpreter inheritance for custom options
package My::Interpreter;
use parent 'MarpaX::AST::Interpreter';

sub new{
    my ($class) = @_;
    return $class->SUPER::new( {
        namespace => 'My::Interpreter',
        'My::Interpreter::structural' => [qw{ S NP VP PP period }],
        'My::Interpreter::literal' => sub { $_[0]->is_literal }
    } );
}

sub My::Interpreter::structural::bracket{
    my (undef, $interpreter, $ast) = @_;
    my $level = $interpreter->context->{level};
    return "\n" . ("  " x $level) . '(. .)' if $ast->id eq 'period';
    return ($ast->id eq 'S' ? '' : "\n") . ("  " x $level) .
        '(' .
        $ast->id . join(' ', map { $interpreter->bracket($_) } @{ $ast->children() } ) .
        ')';
}

sub My::Interpreter::literal::bracket{
    my (undef, $interpreter, $ast) = @_;
    return '(' . $ast->id . ' ' . $ast->text . ')';
}

package main;

my $i = My::Interpreter->new;

@actual = map { my $ast = MarpaX::AST->new($_); $i->bracket($ast) } @values;

$got = join ( "\n", @actual ) . "\n";
$got =~ s{\s+\n}{\n}gms;

eq_or_diff( $got, $expected, 'Ambiguous English sentences, Interpreter pattern' );

done_testing();
