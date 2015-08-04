#!/usr/bin/perl

# Copyright 2015 Ruslan Shvedov

# json decoding
# based on: https://github.com/jeffreykegler/Marpa--R2/blob/master/cpan/t/sl_json.t

# requirements to grammar for round-trip parsers
#   no bare literals (only named)
#   no sequences (delimiters are missed)

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use_ok 'MarpaX::AST';

my $p = MarpaX::JSON->new;

my $json_one_liners = [
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

for my $json_one_liner (@$json_one_liners){
    is $p->reproduce_json($json_one_liner), $json_one_liner, $json_one_liner;
}

my $locations = <<JSON;
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

is $p->reproduce_json($locations), $locations, "locations";

my $image = <<'JSON';
# this is a hash comment to image json file test
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
// c++ style comment at the end
JSON

is $p->reproduce_json($image), $image, "image";

my $big_test = <<'JSON';
// This is c++ style comment to janetter.net json test
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

is $p->reproduce_json($big_test), $big_test, "janetter.net";

# https://commentjson.readthedocs.org/en/latest/
my $commentjson = <<JSON;
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

is $p->reproduce_json($commentjson), $commentjson, "commentjson";

# https://github.com/Dynalon/JsonConfig/blob/master/JsonConfig.Tests/JSON/Arrays.json
my $jsonconfig = <<'JSON';
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

is $p->reproduce_json($jsonconfig), $jsonconfig, "Dynalon/JsonConfig";

# https://code.google.com/p/orthanc/source/browse/Resources/Configuration.json
my $orthanc_config = <<JSON;
{
  /**
   * General configuration of Orthanc
   **/

  // The logical name of this instance of Orthanc. This one is
  // displayed in Orthanc Explorer and at the URI "/system".
  "Name" : "MyOrthanc",

  // Path to the directory that holds the heavyweight files
  // (i.e. the raw DICOM instances)
  "StorageDirectory" : "OrthancStorage",

  // Path to the directory that holds the SQLite index (if unset,
  // the value of StorageDirectory is used). This index could be
  // stored on a RAM-drive or a SSD device for performance reasons.
  "IndexDirectory" : "OrthancStorage",

  // Enable the transparent compression of the DICOM instances
  "StorageCompression" : false,

  // Maximum size of the storage in MB (a value of "0" indicates no
  // limit on the storage size)
  "MaximumStorageSize" : 0,

  // Maximum number of patients that can be stored at a given time
  // in the storage (a value of "0" indicates no limit on the number
  // of patients)
  "MaximumPatientCount" : 0,

  // List of paths to the custom Lua scripts that are to be loaded
  // into this instance of Orthanc
  "LuaScripts" : [
  ],

  // List of paths to the plugins that are to be loaded into this
  // instance of Orthanc (e.g. "./libPluginTest.so" for Linux, or
  // "./PluginTest.dll" for Windows). These paths can refer to
  // folders, in which case they will be scanned non-recursively to
  // find shared libraries.
  "Plugins" : [
  ],


  /**
   * Configuration of the HTTP server
   **/

  // HTTP port for the REST services and for the GUI
  "HttpPort" : 8042,



  /**
   * Configuration of the DICOM server
   **/

  // The DICOM Application Entity Title
  "DicomAet" : "ORTHANC",

  // Check whether the called AET corresponds during a DICOM request
  "DicomCheckCalledAet" : false,

  // The DICOM port
  "DicomPort" : 4242,

  // The default encoding that is assumed for DICOM files without
  // "SpecificCharacterSet" DICOM tag. The allowed values are "Ascii",
  // "Utf8", "Latin1", "Latin2", "Latin3", "Latin4", "Latin5",
  // "Cyrillic", "Windows1251", "Arabic", "Greek", "Hebrew", "Thai",
  // "Japanese", and "Chinese".
  "DefaultEncoding" : "Latin1",

  // The transfer syntaxes that are accepted by Orthanc C-Store SCP
  "DeflatedTransferSyntaxAccepted"     : true,
  "JpegTransferSyntaxAccepted"         : true,
  "Jpeg2000TransferSyntaxAccepted"     : true,
  "JpegLosslessTransferSyntaxAccepted" : true,
  "JpipTransferSyntaxAccepted"         : true,
  "Mpeg2TransferSyntaxAccepted"        : true,
  "RleTransferSyntaxAccepted"          : true,


  /**
   * Security-related options for the HTTP server
   **/

  // Whether remote hosts can connect to the HTTP server
  "RemoteAccessAllowed" : false,

  // Whether or not SSL is enabled
  "SslEnabled" : false,

  // Path to the SSL certificate (meaningful only if SSL is enabled)
  "SslCertificate" : "certificate.pem",

  // Whether or not the password protection is enabled
  "AuthenticationEnabled" : false,

  // The list of the registered users. Because Orthanc uses HTTP
  // Basic Authentication, the passwords are stored as plain text.
  "RegisteredUsers" : {
    // "alice" : "alicePassword"
  },



  /**
   * Network topology
   **/

  // The list of the known DICOM modalities
  "DicomModalities" : {
    /**
     * Uncommenting the following line would enable Orthanc to
     * connect to an instance of the "storescp" open-source DICOM
     * store (shipped in the DCMTK distribution) started by the
     * command line "storescp 2000".
     **/
    // "sample" : [ "STORESCP", "localhost", 2000 ]

    /**
     * A fourth parameter is available to enable patches for a
     * specific PACS manufacturer. The allowed values are currently
     * "Generic" (default value), "StoreScp" (storescp tool from
     * DCMTK), "ClearCanvas", "MedInria", "Dcm4Chee" and
     * "SyngoVia". This parameter is case-sensitive.
     **/
    // "clearcanvas" : [ "CLEARCANVAS", "192.168.1.1", 104, "ClearCanvas" ]
  },

  // The list of the known Orthanc peers
  "OrthancPeers" : {
    /**
     * Each line gives the base URL of an Orthanc peer, possibly
     * followed by the username/password pair (if the password
     * protection is enabled on the peer).
     **/
    // "peer"  : [ "http://localhost:8043/", "alice", "alicePassword" ]
    // "peer2" : [ "http://localhost:8044/" ]
  },

  // Parameters of the HTTP proxy to be used by Orthanc. If set to the
  // empty string, no HTTP proxy is used. For instance:
  //   "HttpProxy" : "192.168.0.1:3128"
  //   "HttpProxy" : "proxyUser:proxyPassword\@192.168.0.1:3128"
  "HttpProxy" : "",


  /**
   * Advanced options
   **/

  // Dictionary of symbolic names for the user-defined metadata. Each
  // entry must map a number between 1024 and 65535 to an unique
  // string.
  "UserMetadata" : {
    // "Sample" : 1024
  },

  // Dictionary of symbolic names for the user-defined types of
  // attached files. Each entry must map a number between 1024 and
  // 65535 to an unique string.
  "UserContentType" : {
    // "sample" : 1024
  },

  // Number of seconds without receiving any instance before a
  // patient, a study or a series is considered as stable.
  "StableAge" : 60,

  // Enable the HTTP server. If this parameter is set to "false",
  // Orthanc acts as a pure DICOM server. The REST API and Orthanc
  // Explorer will not be available.
  "HttpServerEnabled" : true,

  // Enable the DICOM server. If this parameter is set to "false",
  // Orthanc acts as a pure REST server. It will not be possible to
  // receive files or to do query/retrieve through the DICOM protocol.
  "DicomServerEnabled" : true,

  // By default, Orthanc compares AET (Application Entity Titles) in a
  // case-insensitive way. Setting this option to "true" will enable
  // case-sensitive matching.
  "StrictAetComparison" : false,

  // When the following option is "true", the MD5 of the DICOM files
  // will be computed and stored in the Orthanc database. This
  // information can be used to detect disk corruption, at the price
  // of a small performance overhead.
  "StoreMD5ForAttachments" : true,

  // The maximum number of results for a single C-FIND request at the
  // Patient, Study or Series level. Setting this option to "0" means
  // no limit.
  "LimitFindResults" : 0,

  // The maximum number of results for a single C-FIND request at the
  // Instance level. Setting this option to "0" means no limit.
  "LimitFindInstances" : 0,

  // The maximum number of active jobs in the Orthanc scheduler. When
  // this limit is reached, the addition of new jobs is blocked until
  // some job finishes.
  "LimitJobs" : 10,

  // If this option is set to "false", Orthanc will not log the
  // resources that are exported to other DICOM modalities of Orthanc
  // peers in the URI "/exports". This is useful to prevent the index
  // to grow indefinitely in auto-routing tasks.
  "LogExportedResources" : true,

  // Enable or disable HTTP Keep-Alive (deprecated). Set this option
  // to "true" only in the case of high HTTP loads.
  "KeepAlive" : false,

  // If this option is set to "false", Orthanc will run in index-only
  // mode. The DICOM files will not be stored on the drive.
  "StoreDicom" : true,

  // DICOM associations are kept open as long as new DICOM commands
  // are issued. This option sets the number of seconds of inactivity
  // to wait before automatically closing a DICOM association. If set
  // to 0, the connection is closed immediately.
  "DicomAssociationCloseDelay" : 5,

  // Maximum number of query/retrieve DICOM requests that are
  // maintained by Orthanc. The least recently used requests get
  // deleted as new requests are issued.
  "QueryRetrieveSize" : 10,

  // When handling a C-Find SCP request, setting this flag to "false"
  // will enable case-insensitive match for PN value representation
  // (such as PatientName). By default, the search is case-insensitive.
  "CaseSensitivePN" : false
}
JSON

is $p->reproduce_json($orthanc_config), $orthanc_config,
    "heavily commented real-life example from orthanc";

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

            object       ::= <left curly> <right curly>
                           | <left curly> members <right curly>

            <left curly>   ~ '{'
            <right curly>  ~ '}'

            members      ::= pair
            members      ::= members <comma> pair
            <comma>        ~ ','

            pair         ::= string <colon> value
            <colon>        ~ ':'

            value        ::= string
                           | object
                           | number
                           | array
                           | <true>
                           | <false>
                           | <null>

            <true>         ~ 'true'
            <false>        ~ 'false'
            <null>         ~ 'null'

            array        ::= <left square> <right square>
                           | <left square> elements <right square>
            <left square>  ~ '['
            <right square> ~ ']'

            elements     ::= value
            elements     ::= elements <comma> value

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

    $parser->{discardables} = MarpaX::AST::Discardables->new;

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

#    warn MarpaX::AST::dumper($ast);

    return $ast;

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
        else { warn "unknown scalar <$ast>"; return '' }
    }
}

sub decode_json {
    my ($parser, $input) = @_;
    return $parser->decode( $parser->parse($input) );
}

sub reproduce_json {
    my ($parser, $input) = @_;

    my $ast = MarpaX::AST->new( $parser->parse($input), { CHILDREN_START => 3 } );
    my $discardables = $parser->{discardables};

#    warn MarpaX::AST::dumper($discardables);
#    warn $ast->sprint;

    my $json = '';
    my $visited = {};

    $ast->decorate(
        $discardables,
        sub {
            my ($where, $span_before, $ast, $span_after, $ctx) = @_;
            if ($where eq 'head'){
                $json .= $discardables->span_text($span_before, $visited);
            }
            elsif ($where eq 'tail'){
                $json .= $discardables->span_text($span_after, $visited);
            }
            elsif ($where eq 'node'){
                return unless $ast->is_literal;
                $json .= $discardables->span_text($span_before, $visited);
                $json .= $ast->text;
                $json .= $discardables->span_text($span_after, $visited);
            }
        } );

    return $json;
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
