#!/usr/bin/perl

# Copyright 2015 Ruslan Shvedov

# json roundtripping and decoding with export() method
# based on: https://github.com/jeffreykegler/Marpa--R2/blob/master/cpan/t/sl_json.t

# requirements to grammar for round-trip parsers
#   no bare literals (only named)
#   no sequences (delimiters are missed)

use 5.010;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use Marpa::R2;

use JSON::PP; # to avoid eval()'ing data structures in decoding tests

require MarpaX::AST;
require MarpaX::AST::Discardables;

sub test_decode_json {
    my ($parser, $input, $msg) = @_;
    $msg //= $input;

    my $decode_got      = $parser->decode_json($input);
    my $decode_expected = decode_json($input);

    is_deeply $decode_got, $decode_expected, join ' ', $msg, q{decode};
}

sub test_roundtrip_json{
    my ($parser, $input, $desc) = @_;
    eq_or_diff $parser->roundtrip_json($input), $input,
        join ' ', $desc, q{roundtrip};
}

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
    test_roundtrip_json( $p, $json_one_liner, $json_one_liner);
    test_decode_json($p, $json_one_liner);
}

# http://stackoverflow.com/questions/32110156/parsing-complex-json-in-php
my $complex_json = <<END;
{
    "list" : {
        "meta" : {
            "type" : "resource-list",
            "start" : 0,
            "count" : 1
        },
        "resources" : [{
                "resource" : {
                    "classname" : "Quote",
                    "fields" : {
                        "name" : "Wal-Mart Stores, Inc. Common St",
                        "price" : "68.570000",
                        "symbol" : "WMT",
                        "ts" : "1440014635",
                        "type" : "equity",
                        "utctime" : "2015-08-19T20:03:55+0000",
                        "volume" : "16333364"
                    }
                }
            }
        ]
    }
}
END
test_roundtrip_json( $p, $complex_json, 'complex json (SO)');
test_decode_json($p, $complex_json, "complex json (SO)");

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
         "Longitude": -122.02602,
         "Address":   "",
         "City":      "SUNNYVALE",
         "State":     "CA",
         "Zip":       "94085",
         "Country":   "US"
      }
]
JSON

test_roundtrip_json( $p, $locations, "locations");
test_decode_json($p, $locations, "locations");

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

test_roundtrip_json($p, $image, "image");

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

test_roundtrip_json($p, $big_test, "janetter.net");

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

test_roundtrip_json($p, $commentjson, "commentjson");

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

test_roundtrip_json($p, $jsonconfig, "Dynalon/JsonConfig");

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

test_roundtrip_json($p, $orthanc_config,
    "heavily commented real-life example from orthanc");

# https://gist.github.com/etrepat/1289965
my $sublimetext2 = <<JSON;
{
    // Sets the colors used within the text area
    "color_scheme": "Packages/Color Scheme - Default/Monokai.tmTheme",

    // Note that the font_face and font_size are overriden in the platform
    // specific settings file, for example, "Base File (Linux).sublime-settings".
    // Because of this, setting them here will have no effect: you must set them
    // in your User File Preferences.
    "font_face": "Monaco",
    "font_size": 12,

    // Set to false to prevent line numbers being drawn in the gutter
    "line_numbers": true,

    // Set to false to hide the gutter altogether
    "gutter": true,

    // Fold buttons are the triangles shown in the gutter to fold regions of text
    "fold_buttons": true,

    // Hides the fold buttons unless the mouse is over the gutter
    "fade_fold_buttons": true,

    // Columns in which to display vertical rulers
    "rulers": [80],

    // Set to true to turn spell checking on by default
    "spell_check": false,

    // The number of spaces a tab is considered equal to
    "tab_size": 2,

    // Set to true to insert spaces when tab is pressed
    "translate_tabs_to_spaces": true,

    // If translate_tabs_to_spaces is true, use_tab_stops will make tab and
    // backspace insert/delete up to the next tabstop
    "use_tab_stops": true,

    // Set to false to disable detection of tabs vs. spaces on load
    "detect_indentation": true,

    // Set to false to disable automatic indentation
    "auto_indent": true,

    // Set to false to not trim white space added by auto_indent
    "trim_automatic_white_space": true,

    // Set to false for horizontal scrolling
    // NOTE: word_wrap is explicitly turned off in several syntax specific
    // settings, you'll need to set it via your user syntax specific settings
    // to ensure these are overridden.
    "word_wrap": false,

    // Set to false to prevent word wrapped lines from being indented to the same
    // level
    "indent_subsequent_lines": true,

    // Set to false to stop auto pairing quotes, brackets etc
    "auto_match_enabled": true,

    // Set to true to draw a border around the visible rectangle on the minimap.
    // The color of the border will be determined by the "minimapBorder" key in
    // the color scheme
    "draw_minimap_border": true,

    // Set to false to disable highlighting any line with a caret
    "highlight_line": true,

    // Valid values are "smooth", "phase", "blink", "wide" and "solid".
    "caret_style": "smooth",

    // Set to false to disable underlining the brackets surrounding the caret
    "match_brackets": true,

    // Set to false if you'd rather only highlight the brackets when the caret is
    // next to one
    "match_brackets_content": true,

    // Set to false to not highlight square brackets. This only takes effect if
    // matchBrackets is true
    "match_brackets_square": true,

    // Set to false to not highlight curly brackets. This only takes effect if
    // matchBrackets is true
    "match_brackets_braces": true,

    // Enable visualisation of the matching tag in HTML and XML
    "match_tags": true,

    // Additional spacing at the top of each line, in pixels
    "line_padding_top": 0,

    // Additional spacing at the bottom of each line, in pixels
    "line_padding_bottom": 0,

    // Set to false to disable scrolling past the end of the buffer.
    // On OS X, this value is overridden in the platform specific settings, so
    // you'll need to place this line in your user settings to override it.
    "scroll_past_end": true,

    // Set to "none" to turn off drawing white space, "selection" to draw only the
    // white space within the selection, and "all" to draw all white space
    "draw_white_space": "selection",

    // Set to false to turn off the indentation guides.
    // The color and width of the indent guides may be customized by editing
    // the corresponding .tmTheme file, and specifying the colors "guide",
    // "activeGuide" and "stackGuide"
    "draw_indent_guides": true,

    // Controls how the indent guides are drawn, valid options are
    // "draw_normal" and "draw_active". draw_active will draw the indent
    // guides containing the caret in a different color.
    "indent_guide_options": ["draw_active"],

    // Set to true to removing trailing white space on save
    "trim_trailing_white_space_on_save": true,

    // Set to true to ensure the last line of the file ends in a newline
    // character when saving
    "ensure_newline_at_eof_on_save": true,

    // The encoding to use when the encoding can't be determined automatically.
    // ASCII, UTF-8 and UTF-16 encodings will be automatically detected.
    "fallback_encoding": "UTF-8",

    // Encoding used when saving new files, and files opened with an undefined
    // encoding (e.g., plain ascii files). If a file is opened with a specific
    // encoding (either detected or given explicitly), this setting will be
    // ignored, and the file will be saved with the encoding it was opened
    // with.
    "default_encoding": "UTF-8",

    // Determines what character(s) are used to terminate each line in new files.
    // Valid values are 'system' (whatever the OS uses), 'windows' (CRLF) and
    // 'unix' (LF only).
    "default_line_ending": "system",

    // When enabled, pressing tab will insert the best matching completion.
    // When disabled, tab will only trigger snippets or insert a tab.
    // Shift+tab can be used to insert an explicit tab when tab_completion is
    // enabled.
    "tab_completion": true,

    // Enable auto complete to be triggered automatically when typing.
    "auto_complete": true,

    // The maximum file size where auto complete will be automatically triggered.
    "auto_complete_size_limit": 4194304,

    // The delay, in ms, before the auto complete window is shown after typing
    "auto_complete_delay": 50,

    // Controls what scopes auto complete will be triggered in
    "auto_complete_selector": "source - comment",

    // Additional situations to trigger auto complete
    "auto_complete_triggers": [ {"selector": "text.html", "characters": "<"} ],

    // By default, auto complete will commit the current completion on enter.
    // This setting can be used to make it complete on tab instead.
    // Completing on tab is generally a superior option, as it removes
    // ambiguity between committing the completion and inserting a newline.
    "auto_complete_commit_on_tab": true,

    // Controls if auto complete is shown when snippet fields are active.
    // Only relevant if auto_complete_commit_on_tab is true.
    "auto_complete_with_fields": false,

    // By default, shift+tab will only unindent if the selection spans
    // multiple lines. When pressing shift+tab at other times, it'll insert a
    // tab character - this allows tabs to be inserted when tab_completion is
    // enabled. Set this to true to make shift+tab always unindent, instead of
    // inserting tabs.
    "shift_tab_unindent": false,

    // If true, the selected text will be copied into the find panel when it's
    // shown.
    // On OS X, this value is overridden in the platform specific settings, so
    // you'll need to place this line in your user settings to override it.
    "find_selected_text": true
}
JSON
#'

test_roundtrip_json($p, $sublimetext2, "Sublime Text 2 settings");

# https://github.com/ether/etherpad-lite/wiki/Example-Production-Settings.JSON

my $etherpad_lite = <<JSON;
/*
  This file must be valid JSON. But comments are allowed

  Please edit settings.json, not settings.json.template
*/
{
  // Name your instance!
  "title": "My awesome Etherpad site",

  //Ip and port which etherpad should bind at
  "ip": "0.0.0.0",
  "port" : 9001,

  //The Type of the database. You can choose between dirty, postgres, sqlite and mysql
  "dbType" : "mysql",
  "dbSettings" : {
                    "user"    : "root",
                    "host"    : "localhost",
                    "password": "",
                    "database": "store"
                  },

  //the default text of a pad
  "defaultPadText" : "Welcome to my AWESOME site!\n\nThis pad text is synchronized as you type, so that everyone viewing this page sees the same text. This allows you to collaborate seamlessly on documents!\n\nGet involved with Etherpad at http:\/\/etherpad.org\n",

  /* Users must have a session to access pads. This effectively allows only group pads to be accessed. */
  "requireSession" : false,

  /* Users may edit pads but not create new ones. Pad creation is only via the API. This applies both to group pads and regular pads. */
  "editOnly" : false,

  /* if true, all css & js will be minified before sending to the client. This will improve the loading performance massivly,
     but makes it impossible to debug the javascript/css */
  "minify" : true,

  /* How long may clients use served javascript code (in seconds)? Without versioning this
     may cause problems during deployment. Set to 0 to disable caching */
  "maxAge" : 21600, // 60 * 60 * 6 = 6 hours

  /* This is the path to the Abiword executable. Setting it to null, disables abiword.
     Abiword is needed to enable the import/export of pads*/
  "abiword" : "/usr/bin/abiword",

  /* This setting is used if you require authentication of all users.
     Note: /admin always requires authentication. */
  "requireAuthentication": false,

  /* Require authorization by a module, or a user with is_admin set, see below. */
  "requireAuthorization": false,

  /* Users for basic authentication. is_admin = true gives access to /admin.
     If you do not uncomment this, /admin will not be available! */
  "users": {
    "admin": {
      "password": "S3cRet##1",
      "is_admin": true
    }
  },

  /* The log level we are using, can be: DEBUG, INFO, WARN, ERROR */
  "loglevel": "ERROR",

  /* Google Analytics plugin settings */
  "ep_googleanalytics":{
    "gaCode":"UA-2387498"
  }
}
JSON

test_roundtrip_json($p, $etherpad_lite, "etherpad-lite settings");

done_testing();

package MarpaX::JSON;

sub new {

    my ($class) = @_;

    my $parser = bless {}, $class;

    $parser->{grammar} = Marpa::R2::Scanless::G->new({
        source         => \(<<'END_OF_SOURCE'),

        :default     ::= action => [ name, start, length, value ]
        lexeme default = action => [ name, start, length, value ]

        json         ::= object
                       | array

        object       ::= <left curly> <right curly>
                       | <left curly> members <right curly>

        members      ::= pair
        members      ::= members <comma> pair

        pair         ::= string <colon> value

        value        ::= string
                       | object
                       | number
                       | array
                       | <true>
                       | <false>
                       | <null>

        array        ::= <left square> <right square>
                       | <left square> elements <right square>

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

        <left curly>   ~ '{'
        <right curly>  ~ '}'
        <left square>  ~ '['
        <right square> ~ ']'
        <comma>        ~ ','
        <colon>        ~ ':'
        <true>         ~ 'true'
        <false>        ~ 'false'
        <null>         ~ 'null'

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
    });

    return $parser;
}

sub ast { $_[0]->{ast} }

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

sub export {
    my ($parser, $ast) = @_;
#    warn $ast->sprint;
    $ast = $ast->distill({
        # todo: bug or feature? value string, if not skipped, will be passed through
        skip => [qw{ members elements value string comma colon },
            'left curly', 'left square', 'right curly', 'right square' ]
    });

    $parser->{ast} = $ast;

    return $ast->export({
        hash       => [qw{ object }],
        hash_item  => [qw{ pair }],
        array      => [qw{ array }],
        # literals
        true    => bless( do{\(my $o = 1)}, 'JSON::PP::Boolean' ),
        false   => bless( do{\(my $o = 0)}, 'JSON::PP::Boolean' ),
        null    => do{my $o = undef},
        lstring => sub { decode_string(substr $_[0], 1, length($_[0])-2) } # remove quotes
    });
}

# todo: test decoration of ast nodes with comments

sub decode_json {
    my ($parser, $input) = @_;
    my $ast = MarpaX::AST->new( $parser->parse($input) );
    $parser->{ast} = $ast;
    return $parser->export( $ast );
}

sub roundtrip_json {
    my ($parser, $input) = @_;

    my $ast = MarpaX::AST->new( $parser->parse($input), { CHILDREN_START => 3 } );
    my $discardables = $parser->{discardables};

    return $ast->roundtrip($discardables);
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
