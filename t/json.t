#!/usr/bin/perl

# Copyright 2015 Ruslan Shvedov

# json decoding using recursive functions, Visitor and Interpreter
# based on: https://github.com/jeffreykegler/Marpa--R2/blob/master/cpan/t/sl_json.t

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;
use JSON::PP;

require MarpaX::AST;
require MarpaX::AST::Visitor;
require MarpaX::AST::Interpreter;

my $p = MarpaX::JSON->new;

my $jsons = [
    q${"test":"1"}$,
    q${"test":[1,2,3]}$,
    q${"test":true}$,
    q${"test":false}$,
    q${"test":null}$,
    q${"test":null, "test2":"hello world"}$,
    q${"test":"1.25"}$,
    q${"test":"1.25e4"}$,
    q$[]$,
    q${}$,
    q${"test":"1"}$,
    q${ "test":  "\u2603" }$,
];

sub test_decode_json {
    my ($parser, $input, $type, $msg) = @_;
    $msg //= $input;

    my $decode_got      = $parser->decode($input, $type);
    my $decode_expected = decode_json($input);

    unless (is_deeply $decode_got, $decode_expected, join ' ', $msg, qq{decode_$type}){
        warn MarpaX::AST::dumper($decode_got);
    }
}

for my $json (@$jsons){
    test_decode_json($p, $json, 'AoA_traversal');
    test_decode_json($p, $json, 'with_Visitor');
}

my $json = <<'JSON';
[
      {
         "precision": "zip",
         "Latitude":  37.7668,
         "Longitude": -122.3959,
         "Address":   "",
         "City":      "SAN FRANCISCO",
         "State":     "CA",
         "Zip":       "94107",
         "Country":   "US"
      },
      {
         "precision": "zip",
         "Latitude":  37.371991,
         "Longitude": -122.02602,
         "Address":   "",
         "City":      "SUNNYVALE",
         "State":     "CA",
         "Zip":       "94085",
         "Country":   "US"
      }
]
JSON
test_decode_json ($p, $json, 'AoA_traversal', 'Geo data');
test_decode_json ($p, $json, 'with_Visitor', 'Geo data');

$json = <<'JSON';
{
    "Image": {
        "Width":  800,
        "Height": 600,
        "Title":  "View from 15th Floor",
        "Thumbnail": {
            "Url":    "http://www.example.com/image/481989943",
            "Height": 125,
            "Width":  "100"
        },
        "IDs": [116, 943, 234, 38793]
    }
}
JSON
test_decode_json ($p, $json, 'AoA_traversal', 'Image data');
test_decode_json ($p, $json, 'with_Visitor', 'Image data');

$json = <<'JSON';
{
    "source" : "<a href=\"http://janetter.net/\" rel=\"nofollow\">Janetter</a>",
    "entities" : {
        "user_mentions" : [ {
                "name" : "James Governor",
                "screen_name" : "moankchips",
                "indices" : [ 0, 10 ],
                "id_str" : "61233",
                "id" : 61233
            } ],
        "media" : [ ],
        "hashtags" : [ ],
        "urls" : [ ]
    },
    "in_reply_to_status_id_str" : "281400879465238529",
    "geo" : {
    },
    "id_str" : "281405942321532929",
    "in_reply_to_user_id" : 61233,
    "text" : "@monkchips Ouch. Some regrets are harsher than others.",
    "id" : 281405942321532929,
    "in_reply_to_status_id" : 281400879465238529,
    "created_at" : "Wed Dec 19 14:29:39 +0000 2012",
    "in_reply_to_screen_name" : "monkchips",
    "in_reply_to_user_id_str" : "61233",
    "user" : {
        "name" : "Sarah Bourne",
        "screen_name" : "sarahebourne",
        "protected" : false,
        "id_str" : "16010789",
        "profile_image_url_https" : "https://si0.twimg.com/profile_images/638441870/Snapshot-of-sb_normal.jpg",
        "id" : 16010789,
        "verified" : false
    }
}
JSON
test_decode_json ($p, $json, 'AoA_traversal', 'big test');
test_decode_json ($p, $json, 'with_Visitor', 'big test');

done_testing();

package MarpaX::JSON;

use strict;
use warnings;

use Carp;

sub new {

    my ($class) = @_;

    my $parser = bless {}, $class;

    $parser->{grammar} = Marpa::R2::Scanless::G->new(
        {
            source         => \(<<'END_OF_SOURCE'),

            :default     ::= action => [ name, value ]
            lexeme default = action => [ name, value ]

            json         ::= object
                           | array

            object       ::= ('{' '}')
                           | ('{') members ('}')

            members      ::= pair*                  separator => [,]

            pair         ::= string (':') value

            value        ::= string
                           | object
                           | number
                           | array
                           | 'true'
                           | 'false'
                           | 'null'


            array        ::= ('[' ']')
                           | ('[') elements (']')

            elements     ::= value+                 separator => [,]

            number         ~ int
                           | int frac
                           | int exp
                           | int frac exp

            int            ~ digits
                           | '-' digits

            digits         ~ [\d]+

            frac           ~ '.' digits

            exp            ~ e digits

            e              ~ 'e'
                           | 'e+'
                           | 'e-'
                           | 'E'
                           | 'E+'
                           | 'E-'

            string       ::= lstring

            lstring        ~ quote in_string quote
            quote          ~ ["]
            in_string      ~ in_string_char*
            in_string_char ~ [^"] | '\"'

            :discard       ~ whitespace
            whitespace     ~ [\s]+

END_OF_SOURCE
        }
    );

    return $parser;
}

sub parse {
    my ( $parser, $string ) = @_;

    my $re = Marpa::R2::Scanless::R->new(
        {   grammar           => $parser->{grammar},
        }
    );
    $re->read( \$string );
    my $ast = ${ $re->value() };
} ## end sub parse


sub decode {
    my ( $parser, $string, $type ) = @_;
    my $ast = MarpaX::AST->new( $parser->parse($string) );
    my $method = "decode_$type";
    return $parser->$method( $ast );
}

sub distill {
    my ($parser, $ast) = @_;

    my $always_skip = { map { $_ => 1 } qw{ members elements string pair } };

    return $ast->distill({
        skip => sub {
            my ($ast) = @_;
            my $node_id = $ast->id;
            return 1 if exists $always_skip->{$node_id};
            return 1 if $node_id eq 'value' and not $ast->is_literal;
            return 0;
        }
    });

}

sub decode_with_Visitor{
    my ($parser, $ast) = @_;

    $ast = $parser->distill($ast);
    my $v = My::JSON::Decoding::Visitor->new();
#    warn $ast->sprint;
    # we return root (json) node as an array ref
    return shift @{ $v->visit($ast) };
}

sub decode_with_Interpreter{
    my ($parser, $ast) = @_;
    $ast = $parser->distill($ast);
    warn $ast->sprint;
    return
}

sub decode_AoA_traversal {
    my ($parser, $ast) = @_;

    if (ref $ast){
        my ($id, @children) = @$ast;
        if ($id eq 'json'){
            $parser->decode_AoA_traversal(@children);
        }
        elsif ($id eq 'members'){
            return { map { $parser->decode_AoA_traversal($_) } @children };
        }
        elsif ($id eq 'pair'){
            return map { $parser->decode_AoA_traversal($_) } @children;
        }
        elsif ($id eq 'elements'){
            return [ map { $parser->decode_AoA_traversal($_) } @children ];
        }
        elsif ($id eq 'string'){
            return decode_string( substr $children[0]->[1], 1, -1 );
        }
        elsif ($id eq 'number'){
            return $children[0];
        }
        elsif ($id eq 'object'){
            return {} unless @children;
            return $parser->decode_AoA_traversal(@children);
        }
        elsif ($id eq 'array'){
            return [] unless @children;
            return $parser->decode_AoA_traversal(@children);
        }
        else{
            return $parser->decode_AoA_traversal(@children);
        }
    }
    else
    {
        if ($ast eq 'true')    { bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ) }
        elsif ($ast eq 'false'){ bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ) }
        elsif ($ast eq 'null' ){ undef }
        else { croak "unknown scalar <$ast>"; return $ast }
    }
}

sub parse_json {
    my ($parser, $string) = @_;
    return $parser->parse($string);
}

sub decode_string {
    my ($s) = @_;

    $s =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/egxms;
    $s =~ s/\\n/\n/gxms;
    $s =~ s/\\r/\r/gxms;
    $s =~ s/\\b/\b/gxms;
    $s =~ s/\\f/\f/gxms;
    $s =~ s/\\t/\t/gxms;
    $s =~ s/\\\\/\\/gxms;
    $s =~ s{\\/}{/}gxms;
    $s =~ s{\\"}{"}gxms;

    return $s;
} ## end sub decode_string

package My::JSON::Decoding::Visitor;

use strict;
use warnings;
use Carp;

use parent 'MarpaX::AST::Visitor';

# todo: put this in the doc: Visitor is not recursive, so
# no passthrough visitors: each visitor must return a scalar or ref to array or hash
# so the ast must be distilled appropriately

sub visit_value {
    my ($visitor, $ast) = @_;
    if    ($ast->text eq 'true') { bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ) }
    elsif ($ast->text eq 'false'){ bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ) }
    elsif ($ast->text eq 'null') { undef }
    else {
        croak "unknown literal: ", $ast->sprint;
    }
}

sub visit_object{
    my ($visitor, $ast) = @_;
    return { map { $visitor->visit($_) } @{$ast->children} }
}

sub visit_array{
    my ($visitor, $ast) = @_;
    return [ map { $visitor->visit($_) } @{$ast->children} ]
}

sub visit_lstring{
    my ($visitor, $ast) = @_;
    my $contents = $ast->text;
    return MarpaX::JSON::decode_string(
        substr( $contents, 1, length($contents) - 2) );
}

sub visit_number{
    my ($visitor, $ast) = @_;
    return $ast->text;
}

sub visit_json{
    my ($visitor, $ast) = @_;
    return [ map { $visitor->visit($_) } @{$ast->children} ];
}

package My::JSON::Decoding::Interpreter;
use parent 'MarpaX::AST::Dispatching_Interpreter';

1;
