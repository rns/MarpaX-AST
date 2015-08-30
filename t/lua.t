#!/usr/bin/perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use Marpa::R2;

use Carp::Always;

require MarpaX::AST;

my $parser_module_dir;
my $cwd;
BEGIN{
    # set dit for lua source files
    $parser_module_dir = '../MarpaX-Languages-Lua-AST';
    $cwd = qq{./t};
    unless ( $ENV{HARNESS_ACTIVE} ){
        $parser_module_dir = qq{../$parser_module_dir};
        $cwd = q{./};
    }
    # silence "Deep recursion on" warning
    $SIG{'__WARN__'} = sub {
        warn $_[0] unless $_[0] =~ /Deep recursion|Redundant argument in sprintf/ }
}

# todo: loosen the dep on Lua::AST or move to author tests
use lib qq{$parser_module_dir/lib};
require MarpaX::Languages::Lua::AST;

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

my @lua_files = (
    qq{$parser_module_dir/t/MarpaX-Languages-Lua-Parser/echo.lua},
    qq{$parser_module_dir/t/lua5.1-tests/constructs.lua},
    qq{$cwd/corner_cases.lua }
);

for my $lua_file (@lua_files){

    my $lua_src = slurp_file($lua_file);
    my $p = MarpaX::Languages::Lua::AST->new({ roundtrip => 1 });

    my $ast = $p->parse( $lua_src );
#    warn MarpaX::AST::dumper($p->{discardables});
    my $discardables = $p->discardables();

    $ast = MarpaX::AST->new( $ast, { CHILDREN_START => 3 } );

    # is_nulled() in constructs.lua
    if ($lua_file =~ m/constructs.lua$/){
        my $nulled = [];
        my $expected_nulled = [
          [ "block", 806, 0, undef ],
          [ "block", 822, 0, undef ],
          [ "block", 849, 0, undef ],
          [ "block", 867, 0, undef ],
        ];
        $ast->walk({ visit => sub { push @$nulled, $_[0] if $_[0]->is_nulled() } });
        is_deeply $nulled, $expected_nulled, "$lua_file: nulled nodes";
    }

#    warn MarpaX::AST::dumper($ast);

    my $skip_always = { map { $_ => 1 } qw{ statements chunk fieldist qualifiedname } };
    $ast = $ast->distill({
        root => 'chunk',
        # todo: document that context can't be used in skip sub {}, use children instead
        skip => sub {
            my ($ast) = @_;
            return 1 if exists $skip_always->{ $ast->id };
            my @children = @{ $ast->children() };
            # don't skip if $ast if a literal and its first child is bare text
            return 0 if not ref $ast->first_child;
            # skip if $ast has only one child which has the same node id
            return 1 if @children == 1 and $ast->id eq $ast->first_child->id;
        },
    });

    warn $ast->sprint;

    eq_or_diff $ast->roundtrip($discardables), $lua_src,
        qq{$lua_file roundtripped};
}

done_testing();
