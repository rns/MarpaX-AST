#!/usr/bin/perl

# Copyright 2015 Ruslan Shvedov

# json decoding
# based on: https://github.com/jeffreykegler/Marpa--R2/blob/master/cpan/t/sl_json.t

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use_ok 'MarpaX::AST';

my $p = MarpaX::JSON->new;

my $data = $p->parse_json(q${"test":"1"}$);
is($data->{test}, 1);

{
    my $test = q${"test":[1,2,3]}$;
    $data = $p->parse_json(q${"test":[1,2,3]}$);
    is_deeply( $data->{test}, [ 1, 2, 3 ], $test );
}

$data = $p->parse_json(q${"test":true}$);
is($data->{test}, 1);

$data = $p->parse_json(q${"test":false}$);
is($data->{test}, '');

$data = $p->parse_json(q${"test":null}$);
is($data->{test}, undef);

$data = $p->parse_json(q${"test":null, "test2":"hello world"}$);
is($data->{test}, undef);
is($data->{test2}, "hello world");

$data = $p->parse_json(q${"test":"1.25"}$);
is($data->{test}, '1.25', '1.25');

$data = $p->parse_json(q${"test":"1.25e4"}$);
is($data->{test}, '1.25e4', '1.25e4');

$data = $p->parse_json(q$[]$);
is_deeply($data, [], '[]');

$data = $p->parse_json(q${}$);
is_deeply($data, {}, '{}');

$data = $p->parse_json(<<'JSON');
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
         "Longitude": -122.026020,
         "Address":   "",
         "City":      "SUNNYVALE",
         "State":     "CA",
         "Zip":       "94085",
         "Country":   "US"
      }
]
JSON
is_deeply($data, [
    { "precision"=>"zip", Latitude => "37.7668", Longitude=>"-122.3959",
      "Country" => "US", Zip => 94107, Address => '',
      City => "SAN FRANCISCO", State => 'CA' },
    { "precision" => "zip", Longitude => "-122.026020", Address => "",
      City => "SUNNYVALE", Country => "US", Latitude => "37.371991",
      Zip => 94085, State => "CA" }
], 'Geo data');

$data = $p->parse_json(<<'JSON');
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
is_deeply($data, {
    "Image" => {
        "Width" => 800, "Height" => 600,
        "Title" => "View from 15th Floor",
        "Thumbnail" => {
            "Url" => "http://www.example.com/image/481989943",
            "Height" => 125,
            "Width" => 100,
        },
        "IDs" => [ 116, 943, 234, 38793 ],
    }
}, 'is_deeply test');

my $big_test = <<'JSON';
// This is c++ style comment
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
    /* This is c style comment */
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
$data = $p->parse_json($big_test);

is_deeply $data, eval q{
{
    'source' => '<a href="http://janetter.net/" rel="nofollow">Janetter</a>',
    'geo' => {},
    'in_reply_to_user_id_str' => '61233',
    'id_str' => '281405942321532929',
    'entities' => {
        'hashtags' => [],
        'media' => [],
        'user_mentions' => [
            {
                'name' => 'James Governor',
                'id' => '61233',
                'id_str' => '61233',
                'indices' => [
                    '0',
                    '10'
                ],
                'screen_name' => 'moankchips'
            }
        ],
        'urls' => []
    },
    'created_at' => 'Wed Dec 19 14:29:39 +0000 2012',
    'in_reply_to_status_id_str' => '281400879465238529',
    'text' => '@monkchips Ouch. Some regrets are harsher than others.',
    'user' => {
        'protected' => '',
        'name' => 'Sarah Bourne',
        'verified' => '',
        'id' => '16010789',
        'id_str' => '16010789',
        'profile_image_url_https' => 'https://si0.twimg.com/profile_images/638441870/Snapshot-of-sb_normal.jpg',
        'screen_name' => 'sarahebourne'
    },
    'in_reply_to_user_id' => '61233',
    'id' => '281405942321532929',
    'in_reply_to_status_id' => '281400879465238529',
    'in_reply_to_screen_name' => 'monkchips'
}
}, "big test";

$data = $p->parse_json(<<'JSON');
{ "test":  "\u2603" }
JSON
is($data->{test}, "\x{2603}", 'Unicode char');

# commented json tests

# https://commentjson.readthedocs.org/en/latest/
$data = $p->parse_json(<<'JSON');
{
    "name": "Vaidik Kapoor", # Person's name
    "location": "Delhi, India", // Person's location

    # Section contains info about
    // person's appearance
    "appearance": {
        "hair_color": "black",
        "eyes_color": "black",
        "height": "6"
    }
}
JSON

is_deeply $data, eval q{
    {
        'name' => 'Vaidik Kapoor',
        'location' => 'Delhi, India',
        'appearance' => {
            'hair_color' => 'black',
            'height' => '6',
            'eyes_color' => 'black'
        }
    }
}, "commentjson";


# https://github.com/Dynalon/JsonConfig/blob/master/JsonConfig.Tests/JSON/Arrays.json

$data = $p->parse_json(<<'JSON');
# Comments can be placed when ~~a line starts with (whitespace +)~~ anywhere
// hint: ~~strikethrough text~~ https://help.github.com/articles/github-flavored-markdown/
{
    "Default" : "arrays",
    # This is a comment
    "Fruit1":
    {
        "Fruit" :   ["apple", "banana", "melon"]
    },
    "Fruit2":
    {
        # This too is a comment
        "Fruit" :   ["apple", "cherry", "coconut"]
    },
    "EmptyFruit":
    {
        "Fruit" : []
    },
    "Coords1":
    {
        "Pairs": [
            {
                "X" : 1,
                "Y" : 1
            },
            {
                "X" : 2,
                "Y" : 3
            }
        ]
    },
    "Coords2":
    {
        "Pairs": []
    }
}
JSON


is_deeply $data, eval q{
    {
      Coords1 => {
        Pairs => [
          {
            X => 1,
            Y => 1
          },
          {
            X => 2,
            Y => 3
          }
        ]
      },
      Coords2 => {
        Pairs => []
      },
      Default => "arrays",
      EmptyFruit => {
        Fruit => []
      },
      Fruit1 => {
        Fruit => [
          "apple",
          "banana",
          "melon"
        ]
      },
      Fruit2 => {
        Fruit => [
          "apple",
          "cherry",
          "coconut"
        ]
      }
    }
}, 'Dynalon/JsonConfig';

done_testing();

package MarpaX::JSON;

sub new {

    my ($class) = @_;

    my $parser = bless {}, $class;

    $parser->{grammar} = Marpa::R2::Scanless::G->new(
        {
            source         => \(<<'END_OF_SOURCE'),

            :default     ::= action => [ name, start, length, value ]
            lexeme default = action => [ name, start, length, value ]

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

            :discard       ~ whitespace event => 'whitespace'
            whitespace     ~ [\s]+

            :discard       ~ <C style comment> event => 'C style comment'
            # source: https://github.com/jddurand/MarpaX-Languages-C-AST/blob/master/lib/MarpaX/Languages/C/AST/Grammar/ISO_ANSI_C_2011.pm
            <C style comment> ~ '/*' <comment interior> '*/'
            <comment interior> ~
                <optional non stars>
                <optional star prefixed segments>
                <optional pre final stars>
            <optional non stars> ~ [^*]*
            <optional star prefixed segments> ~ <star prefixed segment>*
            <star prefixed segment> ~ <stars> [^/*] <optional star free text>
            <stars> ~ [*]+
            <optional star free text> ~ [^*]*
            <optional pre final stars> ~ [*]*

            :discard       ~ <Cplusplus style comment> event => 'Cplusplus style comment'
            # source: https://github.com/jddurand/MarpaX-Languages-C-AST/blob/master/lib/MarpaX/Languages/C/AST/Grammar/ISO_ANSI_C_2011.pm
            <Cplusplus style comment> ~ '//' <Cplusplus comment interior>
            <Cplusplus comment interior> ~ [^\n]*

            :discard       ~ <hash comment> event => 'hash comment'
            # source: https://github.com/jeffreykegler/Marpa--R2/blob/master/cpan/t/sl_calc.t
            <hash comment> ~ <terminated hash comment> | <unterminated
               final hash comment>
            <terminated hash comment> ~ '#' <hash comment body> <vertical space char>
            <unterminated final hash comment> ~ '#' <hash comment body>
            <hash comment body> ~ <hash comment char>*
            <vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
            <hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]

END_OF_SOURCE
        }
    );

    $parser->{discardables} = MarpaX::AST::Discardables->new;

    return $parser;
}

sub parse {
    my ( $parser, $json ) = @_;

    my $recce = Marpa::R2::Scanless::R->new(
        {
            grammar => $parser->{grammar},
            trace_terminals => 0,
        }
    );

    my $json_ref    = \$json;
    my $json_length = length $json;
    my $pos         = $recce->read($json_ref);

    READ: while (1) {
        EVENT:
        for my $event (@{$recce->events}){
            my ($name, $start, $end) = @{$event};
            my $length = $end - $start;
            my $text = $recce->literal( $start, $length );
            $parser->{discardables}->post($name, $start, $length, $text);
            next EVENT;
        }
        last READ if ($pos >= $json_length);
        $pos = $recce->resume($pos);
    }

#    warn MarpaX::AST::dumper($parser->{discardables});

    my $ast = ${ $recce->value() };
    return $parser->decode ( $ast );

} ## end sub parse

sub decode {
    my $parser = shift;

    my $ast  = shift;

    if (ref $ast){
        my ($id, $start, $length, @nodes) = @$ast;
        if ($id eq 'json'){
            $parser->decode(@nodes);
        }
        elsif ($id eq 'members'){
            return { map { $parser->decode($_) } @nodes };
        }
        elsif ($id eq 'pair'){
            return map { $parser->decode($_) } @nodes;
        }
        elsif ($id eq 'elements'){
            return [ map { $parser->decode($_) } @nodes ];
        }
        elsif ($id eq 'string'){
            return decode_string( substr $nodes[0]->[3], 1, -1 );
        }
        elsif ($id eq 'number'){
            return $nodes[0];
        }
        elsif ($id eq 'object'){
            return {} unless @nodes;
            return $parser->decode($_) for @nodes;
        }
        elsif ($id eq 'array'){
            return [] unless @nodes;
            return $parser->decode($_) for @nodes;
        }
        else{
            return $parser->decode($_) for @nodes;
        }
    }
    else
    {
        if ($ast eq 'true' or $ast eq 'false'){ return $ast eq 'true' }
        elsif ($ast eq 'null' ){ return undef }
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

1;
