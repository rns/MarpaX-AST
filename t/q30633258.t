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
# say $ast->sprint;

my $expected_distilled = <<EOS;
 root
   Testing.User
   Info
     Testing.Info
     Name
       System.String
       Matt
     Age
       System.Int32
       21
   Description
     System.String
     This is some description
EOS

my $dast = $ast->distill({
    root => 'root',
    skip => [ 'start', 'values', 'value', 'subseries' ],
    dont_visit => [
        'series'
        ],
});

say MarpaX::AST::dumper($dast);

my $got_distilled = $dast->sprint;

is $got_distilled, $expected_distilled, "complex-string-splitting, SO Question 30633258";

done_testing();
