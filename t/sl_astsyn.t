#!/usr/bin/perl
# Copyright 2014 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

# Synopsis for DSL pod of SLIF

use 5.010;
use strict;
use warnings;

use Test::More tests => 4;

## no critic (ErrorHandling::RequireCarping);

# Marpa::R2::Display
# name: SLIF DSL synopsis

use Marpa::R2;

my $grammar = Marpa::R2::Scanless::G->new({
source        => \(<<'END_OF_SOURCE'),
    :default ::= action => [ name, value ]
    lexeme default = action => [ value ] latm => 1
    # string, string, int, int, array_ref

    Script ::= Expression+ separator => comma
    comma ~ [,]
    Expression ::=
        Number name => 'num'
        | ( '(' ) Expression ( ')' ) name => '()' assoc => group
       || Expression ( '**' ) Expression name => '**' assoc => right
       || Expression ( '*' ) Expression name => '*'
        | Expression ( '/' ) Expression name => '/'
       || Expression ( '+' ) Expression name => '+'
        | Expression ( '-' ) Expression name => '-'

    Number ~ [\d]+
    :discard ~ whitespace
    whitespace ~ [\s]+
    # allow comments
    :discard ~ <hash comment>
    <hash comment> ~ <terminated hash comment> | <unterminated
       final hash comment>
    <terminated hash comment> ~ '#' <hash comment body> <vertical space char>
    <unterminated final hash comment> ~ '#' <hash comment body>
    <hash comment body> ~ <hash comment char>*
    <vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
    <hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
END_OF_SOURCE
});

my @tests = (
    [   '42*2+7/3, 42*(2+7)/3, 2**7-3, 2**(7-3)' =>
            qr/\A 86[.]3\d+ \s+ 126 \s+ 125 \s+ 16\z/xms
    ],
    [   '42*3+7, 42 * 3 + 7, 42 * 3+7' => qr/ \s* 133 \s+ 133 \s+ 133 \s* /xms
    ],
    [   '15329 + 42 * 290 * 711, 42*3+7, 3*3+4* 4' =>
            qr/ \s* 8675309 \s+ 133 \s+ 25 \s* /xms
    ],
);

use YAML;
sub ast_evaluate{
    my $ast = shift;
    say Dump $ast;
}

for my $test (@tests) {
    my ( $input, $output_re ) = @{$test};
    my $ast = $grammar->parse ( \$input );
    # process ast
    my $value = ast_evaluate( $ast );
    Test::More::like( $value, $output_re, 'Value of scannerless parse' );
}

