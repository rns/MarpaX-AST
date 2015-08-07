# Source: http://stackoverflow.com/questions/30633258/complex-string-splitting

# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

my $g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

    :default ::= action => [ name, start, length, value ]
    lexeme default = action => [ name, start, length, value] latm => 1

    start ::= series+

    series  ::= ( '[' ) name ( ']' '|' ) values

    name    ~ 'Testing.User' | 'System.String' | 'Testing.Info' | 'System.Int32'

    values  ::= value+ separator => [|]

    value   ::= series | subseries | string

    subseries ::= subname ( ':' '(' ) value ( ')' )

    subname   ~ 'Info' | 'Name' | 'Age' | 'Description'

    string    ~ [\w ]+

    :discard ~ whitespace
    whitespace ~ [\s]+

END_OF_SOURCE
} );

my $input = <<EOI;
[Testing.User]|Info:([Testing.Info]|Name:([System.String]|Matt)|Age:([System.Int32]|21))|Description:([System.String]|This is some description)
EOI

my $ast = $g->parse( \$input, { trace_terminals => 0 } );

use MarpaX::AST;

$ast = MarpaX::AST->new( $$ast, { CHILDREN_START => 3 } );

#say MarpaX::AST::dumper($ast);
#say $ast->sprint;

my $expected_distilled = <<EOS;
 root
   name 'Testing.User'
   subname
     #text 'Info'
     name 'Testing.Info'
     subname
       #text 'Name'
       name 'System.String'
       string 'Matt'
     subname
       #text 'Age'
       name 'System.Int32'
       string '21'
   subname
     #text 'Description'
     name 'System.String'
     string 'This is some description'
EOS

$ast = $ast->distill({
    root => 'root',
    skip => [ qw{ start values value subseries } ],
# todo: explain dont_visit vs. skip
    dont_visit => [ qw{ series } ],
#    bare_literals => 1 # as in "make specified literals bare literals"
#    bare_literals => [ name, string ] # bare
});


# todo: make a data structure and test with is_deeply
=pod DSL to convert AST to a data structure

 node_id/node_id => hash/pair

 node_id => array/item

 node_id => pass-through

 ... all unspecified node ID’s => pass-through

=cut

#say MarpaX::AST::dumper($ast);
say $ast->sprint;

my $got_distilled = $ast->sprint;

is $got_distilled, $expected_distilled, "complex-string-splitting, SO Question 30633258";

done_testing();
