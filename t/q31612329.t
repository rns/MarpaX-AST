# Source: http://stackoverflow.com/questions/30633258/complex-string-splitting

# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

my $g = Marpa::R2::Scanless::G->new( { source => \(<<'END_OF_SOURCE'),

    :default ::= action => [ name, value ]
    lexeme default = action => [ name, value ] latm => 1

    scutil ::= 'scutil' '> open' '> show' path dict
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

#say MarpaX::AST::dumper($ast);

$ast = $ast->distill({
    root => '',
    skip => [ 'path', '#text', 'value', 'items', 'pairs', 'signature_item_value' ],
});

#say "# distilled:\n", MarpaX::AST::dumper($ast);

#say $ast->sprint;

sub make_hash_map{
    my ($ast) = @_;

    if ($ast->is_literal){ return $ast->text }
    else{
        my $id = $ast->id;
        my $children = $ast->children;
        # root -- just pass through
        if ($id eq 'scutil'){
            return make_hash_map(@$children);
        }
        # hash
        elsif ($id eq 'dict' or $id eq 'signature'){
            return { map { make_hash_map($_) } @$children };
        }
        # hash item
        elsif ($id eq 'pair' or $id eq 'signature_item'){
            my ($k, $v) = @{ $ast->children() };
            return $k->text => make_hash_map($v);
        }
        # array
        elsif ($id eq 'array'){
            return [
                # todo: item nodes not sorted by index
                # by checking of the returned array item is [ $ix, $value ] or $value
                map { make_hash_map($_) } @$children
            ];
        }
        # array item
        elsif ($id eq 'item'){
            my ($i, $v) = map { $ast->child($_) } (0, 1);
            # this assumes that item nodes are sorted by index
            return make_hash_map($v);
        }
        # pass through
        else {
            return make_hash_map($_) for @$children;
        }
    }
}

my $got_hash_map = make_hash_map($ast);

#warn "got_hash_map: ", MarpaX::AST::dumper( $got_hash_map );

# todo: notify the asker ?

my $expected_hash_map = {
  ARPResolvedHardwareAddress => "00:1b:c0:4a:82:f9",
  ARPResolvedIPAddress => "10.10.0.254",
  AdditionalRoutes => [
    {
      DestinationAddress => "10.10.0.146",
      SubnetMask => "255.255.255.255"
    },
    {
      DestinationAddress => "169.254.0.0",
      SubnetMask => "255.255.0.0"
    }
  ],
  Addresses => [
    "10.10.0.146"
  ],
  ConfirmedInterfaceName => "en0",
  InterfaceName => "en0",
  NetworkSignature => {
    "IPv4.Router" => "10.10.0.254",
    "IPv4.RouterHardwareAddress" => "00:1b:c0:4a:82:f9"
  },
  Router => "10.10.0.254",
  SubnetMasks => [
    "255.255.255.0"
  ]
};

is_deeply $expected_hash_map, $got_hash_map, "SO question 31612329";

done_testing();
