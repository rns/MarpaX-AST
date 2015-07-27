# Source: http://stackoverflow.com/questions/30633258/complex-string-splitting

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

SKIP: {

skip "unimplemented", 1;

my $g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

    :default ::= action => [ name, value]
    lexeme default = action => [ name, value] latm => 1

    scutil ::= 'scutil' '> open' '> show' path '<dictionary>' '{' pairs '}'
    path ~ [\w/:\-]+

    pairs ::= pair+

    pair ::= name ':' value

    dict  ::= '<dictionary>' '{' pairs '}'
    array ::= '<array>' '{' items  '}'

    items ::= item+
    item ::= index ':' value
    index ~ [\d]+

    value ::= ip | mac | interface | signature | array | dict

    ip ~ octet '.' octet '.' octet '.' octet
    octet ~ [\d]+

    mac ~ [a-z0-9][a-z0-9]':'[a-z0-9][a-z0-9]':'[a-z0-9][a-z0-9]':'[a-z0-9][a-z0-9]':'[a-z0-9][a-z0-9]':'[a-z0-9][a-z0-9]

    interface ~ [\w]+

    signature ::= signature_item+ separator => [;]
    signature_item ::= signature_item_name '=' signature_item_value
    signature_item_name ~ [\w\.]+
    signature_item_value ::= ip | mac

    name ~ [\w]+

    :discard ~ whitespace
    whitespace ~ [\s]+

END_OF_SOURCE
} );

my $input = <<EOI;
scutil
> open
> show State:/Network/Service/0F70B221-EEF7-4ACC-96D8-ECBA3A15F132/IPv4
<dictionary> {
  ARPResolvedHardwareAddress : 00:1b:c0:4a:82:f9
  ARPResolvedIPAddress : 10.10.0.254
  AdditionalRoutes : <array> {
    0 : <dictionary> {
      DestinationAddress : 10.10.0.146
      SubnetMask : 255.255.255.255
    }
    1 : <dictionary> {
      DestinationAddress : 169.254.0.0
      SubnetMask : 255.255.0.0
    }
  }
  Addresses : <array> {
    0 : 10.10.0.146
  }
  ConfirmedInterfaceName : en0
  InterfaceName : en0
  NetworkSignature : IPv4.Router=10.10.0.254;IPv4.RouterHardwareAddress=00:1b:c0:4a:82:f9
  Router : 10.10.0.254
  SubnetMasks : <array> {
    0 : 255.255.255.0
  }
}
EOI

use MarpaX::AST;
my $ast = $g->parse( \$input, { trace_terminals => 0 } );

$ast = MarpaX::AST->new( $$ast );

say $ast->sprint;

my $got_distilled = $ast->distill({
    root => 'root',
    skip => [ '#text', 'value', 'item' ],
})->sprint;

say $ast->sprint;

}

done_testing();
