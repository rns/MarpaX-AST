# Source: http://stackoverflow.com/questions/30633258/complex-string-splitting

use 5.010;
use strict;
use warnings;

use Test::More;

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Terse = 1;
$Data::Dumper::Deepcopy = 1;

use Marpa::R2;

my $g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

    :default ::= action => [ name, value ]
    lexeme default = action => [ name, value] latm => 1

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

$ast = MarpaX::AST->new( $$ast );

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

my $got_distilled = $ast->distill({
    root => 'root',
    skip => [ 'start', 'values', 'value', 'subseries' ],
    dont_visit => [
        'series'
        ],
    literals_as_text => 1,
})->sprint;

is $got_distilled, $expected_distilled, "complex-string-splitting, SO Question 30633258";

done_testing();
