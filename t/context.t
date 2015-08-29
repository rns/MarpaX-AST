#!/usr/bin/perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

require MarpaX::AST;

my $ast_AoA = [
    'root',
    [ 'child1', 'value1' ],
    [ 'child2',
        [ 'child21', [ 'child211', 'value211' ] ],
        [ 'child22', 'value22' ],
        [ 'child23', [ 'child231', 'value231' ] ],
    ],
    [ 'child3',
        [ 'child31', 'value31' ],
        [ 'child32', 'value32' ],
        [ 'child33', [ 'child331', 'value331' ] ],
        [ 'child34', 'value34' ],
    ],
];

my $ast = MarpaX::AST->new($ast_AoA);

my $parents = {
    child1 => 'root',
    child2 => 'root',
    child21 => 'child2',
    child211 => 'child21',
    child231 => 'child23',
    child22 => 'child2',
    child23 => 'child2',
    child3 => 'root',
    child31 => 'child3',
    child32 => 'child3',
    child33 => 'child3',
    child331 => 'child33',
    child34 => 'child3',
};

my $siblings = {
    child1 => [qw{ child1 child2 child3 }],
    child2 => [qw{ child1 child2 child3 }],
    child3 => [qw{ child1 child2 child3 }],
    child21 => [qw{ child21 child22 child23 }],
    child211 => [qw{ child211 }],
    child22 => [qw{ child21 child22 child23 }],
    child23 => [qw{ child21 child22 child23 }],
    child231 => [qw{ child231 }],
    child31 => [qw{ child31 child32 child33 child34 }],
    child32 => [qw{ child31 child32 child33 child34 }],
    child33 => [qw{ child31 child32 child33 child34 }],
    child331 => [qw{ child331 }],
    child34 => [qw{ child31 child32 child33 child34 }],
};

#warn $ast->sprint;

$ast->walk({
    visit => sub {
        my ($ast, $ctx) = @_;

#        warn "# node: ", $ast->id;

        if ($ast->is_root){
            ok not (defined $ctx->{parent}), "parent of root not defined";
            return;
        }

        ok defined $ctx->{parent}, join ' ', "parent of", $ast->id, "defined";

        is $ctx->{parent}->id, $parents->{ $ast->id },
            join ' ', "parent of", $ast->id, "is", $ctx->{parent}->id;

        my $got_siblings = [ map { $_->id } @{ $ctx->{siblings} } ];
        is_deeply $got_siblings, $siblings->{ $ast->id }, join ' ', "siblings of", $ast->id, "are [", join(', ', @$got_siblings), ']';

#        warn "# at $ctx->{depth}: parents of ", $ast->id, ":\n", join ("\n", map { $_->id } @{ $ctx->{parent} } );
    }
});

done_testing();



