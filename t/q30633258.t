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

    series  ::= name ( '|' ) values

    name    ~ '[Testing.User]' | '[System.String]' | '[Testing.Info]' | '[System.Int32]'

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

#warn MarpaX::AST::dumper($ast);
#warn $ast->sprint;

my $expected_distilled = <<EOS;
 root
   #text '[Testing.User]'
   Info
     #text '[Testing.Info]'
     Name
       #text '[System.String]'
       #text 'Matt'
     Age
       #text '[System.Int32]'
       #text '21'
   Description
     #text '[System.String]'
     #text 'This is some description'
EOS

$ast = $ast->distill({
    root => 'root',
# todo: fails with value and/or subname and qw{start values} in skip =>
    skip => [ qw{ start values value subseries } ],
# todo: explain dont_visit vs. skip
# todo: fails with subname
    dont_visit => [ qw{ series } ],
    append_literals_as_parents => 1 # applies to all literals
# todo: test append_literals_as_parents => 1
#    append_literals_as_parents => [ qw{ name subname string } ]
});

# name, [ children ]

#warn MarpaX::AST::dumper($ast);
warn $ast->sprint;

my $got_distilled = $ast->sprint;

is $got_distilled, $expected_distilled, "SO Question 30633258: distill";

my $exported = $ast->export(
    { array => [ 'root', 'Info', 'Name', 'Age', 'Description' ]
# { named_array => [ 'Info', 'Name', 'Age', 'Description' ] }
#    { array => [ 'root', 'name', 'subname', '#text', 'subseries' ]
});

warn MarpaX::AST::dumper($exported);

my $expected_exported = eval q{
[
  "Testing.User",
  [
    "Info",
    "Testing.Info",
    [
      "Name",
      "System.String",
      "Matt"
    ],
    [
      "Age",
      "System.Int32",
      21
    ]
  ],
  [
    "Description",
    "System.String",
    "This is some description"
  ]
]
};

is_deeply $exported, $expected_exported, "SO Question 30633258: export";

done_testing();
