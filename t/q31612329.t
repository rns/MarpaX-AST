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

sub ast_validate{
    my ($ast, $schema) = @_;
    # $ast must have all nodes in schema
    # every child of a hash node must validate as hash_item
    # every child of an array node must validate as array_item
    # hash_item node must have exactly two children, the first of which must be a literal
    # array_item node must have exactly two children, the first of which must be a literal
    # or a single child
    # todo: undefs?
    return 1;
}

use Carp::Assert;
use Carp::Always;

sub internalize{
    my ($external_schema) = @_;
    # convert array refs to hashes for node id lookup
    while (my ($k, $v) = each %$external_schema){
        my $v_href = {};
        $v_href->{$_} = 1 for @$v;
        $external_schema->{$k} = $v_href;
    }
    return $external_schema;
}

sub ast_export{
    my ($ast, $external_schema) = @_;

    state $schema = internalize($external_schema);

    if ($ast->is_literal){ return $ast->text }
    else{
        my $node_id = $ast->id;
        my $children = $ast->children;
        if (exists $schema->{hash}->{$node_id}){
            return { map { ast_export($_, $schema) } @$children };
        }
        elsif (exists $schema->{hash_item}->{$node_id}){
            my ($key, $value) = @$children;
            return $key->text => ast_export($value, $schema);
        }
        elsif (exists $schema->{array}->{$node_id}){
            my $items = [];
            map {
                my $item = ast_export($_, $schema);
                # todo: validate $ast according to $schema
                # assuming pre-validation
                # array item is indexed [ $index, $value ]
                if (ref $item) { $items->[ $item->[0] ] = $item->[1] }
                # array item is bare (scalar)
                else { push @$items, $item }
            } @$children;
            return $items;
        }
        elsif (exists $schema->{array_item}->{$node_id}){
#            return [ map { ast_export($_, $schema), @$children ];
            if (@$children == 2){
                my ($index, $value) = @$children;
                return [ $index->text, ast_export($value, $schema) ];
            }
            elsif(@$children == 1){
                return ast_export($children->[0], $schema);
            }
        }
        else{ return ast_export($_, $schema) for @$children }
    }
}

my $exported = ast_export($ast, {
    hash => [ 'dict', 'signature' ], hash_item => [ qw{ pair signature_item } ],
    array => [ qw{ array } ], array_item => [ qw{ item } ] } );

#warn "exported:", MarpaX::AST::dumper( $exported );

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

is_deeply $exported, $expected_hash_map, "SO question 31612329";

done_testing();
