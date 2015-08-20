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

    is_deeply $decode_got, $decode_expected, join ' ', $msg, q{decode $type};
}

for my $json (@$jsons){
    test_decode_json($p, $json, 'AoA');
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
test_decode_json ($p, $json, 'AoA', 'Geo data');

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
test_decode_json ($p, $json, 'AoA', 'Geo data');

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
test_decode_json ($p, $json, 'AoA', 'big test');

done_testing();

package MarpaX::JSON;

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


sub decode{
    my ( $parser, $string, $type ) = @_;
    my $ast = MarpaX::AST->new( $parser->parse($string) );
    my $method = "decode_$type";
    return $parser->$method( $ast );
}

sub decode_AoA {
    my $parser = shift;

    my $ast  = shift;

    if (ref $ast){
        my ($id, @nodes) = @$ast;
        if ($id eq 'json'){
            $parser->decode_AoA(@nodes);
        }
        elsif ($id eq 'members'){
            return { map { $parser->decode_AoA($_) } @nodes };
        }
        elsif ($id eq 'pair'){
            return map { $parser->decode_AoA($_) } @nodes;
        }
        elsif ($id eq 'elements'){
            return [ map { $parser->decode_AoA($_) } @nodes ];
        }
        elsif ($id eq 'string'){
            return decode_string( substr $nodes[0]->[1], 1, -1 );
        }
        elsif ($id eq 'number'){
            return $nodes[0];
        }
        elsif ($id eq 'object'){
            return {} unless @nodes;
            return $parser->decode_AoA($_) for @nodes;
        }
        elsif ($id eq 'array'){
            return [] unless @nodes;
            return $parser->decode_AoA($_) for @nodes;
        }
        else{
            return $parser->decode_AoA($_) for @nodes;
        }
    }
    else
    {
        if ($ast eq 'true')    { bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ) }
        elsif ($ast eq 'false'){ bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ) }
        elsif ($ast eq 'null' ){ undef }
        else { warn "unknown scalar <$ast>"; return $ast }
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

package My::Visitor;
use parent 'MarpaX::AST::Visitor';

package My::Interpreter;
use parent 'MarpaX::AST::Interpreter';

1;
