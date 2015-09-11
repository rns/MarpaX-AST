# Source: https://gist.github.com/spacebat/f1dbb340fc62facf4a0a

# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

my $g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),
:default ::= action => [ name, value ]
lexeme default = action => [ name, value] latm => 1

rules      ::= rule+ separator => eol

rule       ::= cmd_type user_list | cmd_type all | user_decl

user_decl  ::= user '=' user_list
user_list  ::= user_spec+
user_spec  ::= user | list_ref

list_ref   ~ '@' username
user       ~ username

cmd_type   ~ 'Deny' | 'Allow'
username   ~ [\w]+

all        ~ 'all' | 'everybody'
:lexeme ~ all priority => 1

:discard   ~ ws
ws         ~ [ \t]+

eol        ~ [\n]+
END_OF_SOURCE
} );

my $input = <<'EOI';
super_admins = me
admins = @super_admins admin root administrator peter
Deny all
Allow @admins carter
EOI

my $ast = $g->parse( \$input, { trace_terminals => 0 } );

use MarpaX::AST;

$ast = MarpaX::AST->new( $$ast );

$ast = $ast->distill({ skip => [ qw{ user_spec } ] });

warn $ast->sprint;
