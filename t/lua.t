#!/usr/bin/perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use Marpa::R2;

use_ok 'MarpaX::AST';

my $parser_module_dir;
BEGIN{
    # set dit for lua source files
    $parser_module_dir = '../MarpaX-Languages-Lua-AST';
    $parser_module_dir = qq{../$parser_module_dir}
        unless $ENV{HARNESS_ACTIVE};
    # silence "Deep recursion on" warning
    $SIG{'__WARN__'} = sub {
        warn $_[0] unless $_[0] =~ /Deep recursion|Redundant argument in sprintf/ }
}

use lib qq{$parser_module_dir/lib};

use_ok 'MarpaX::Languages::Lua::AST';

sub slurp_file{
    my ($fn) = @_;
    open my $fh, $fn or die "Can't open $fn: $@.";
    my $slurp = do { local $/ = undef; <$fh> };
    close $fh;
    return $slurp;
}

#my $lua_parser_dir = qq{$parser_module_dir/t/MarpaX-Languages-Lua-Parser};
#my @lua_files = qw{ echo.lua };

my $lua_dir = qq{$parser_module_dir/t/lua5.1-tests};
my @lua_files = qw{ constructs.lua };

#my $lua_dir = $ENV{HARNESS_ACTIVE} ?  't' : '.';
#my @lua_files = qw{ corner_cases.lua };

for my $lua_file (@lua_files){

    my $lua_src = slurp_file( qq{$lua_dir/$lua_file} );
    my $p = MarpaX::Languages::Lua::AST->new;

    my $ast = $p->parse( $lua_src );
#    warn MarpaX::AST::dumper($p->{discardables});
    my $discardables = $p->{discardables};

    $ast = MarpaX::AST->new( $ast, { CHILDREN_START => 3 } );

    # test for is_nulled() in constructs.lua
    if ($lua_file =~ m/constructs.lua$/){
        my $nulled = [];
        my $expected_nulled = [
          [ "block", 806, 0, undef ],
          [ "block", 822, 0, undef ],
          [ "block", 849, 0, undef ],
          [ "block", 867, 0, undef ],
        ];
        $ast->walk({ visit => sub { push @$nulled, $_[0] if $_[0]->is_nulled() } });
        is_deeply $nulled, $expected_nulled, "nulled nodes";
    }

#    warn MarpaX::AST::dumper($ast);
#    warn $ast->sprint;
    $ast = $ast->distill({
        root => 'chunk',
        skip => [ 'statements', 'chunk' ],
    });

#        warn $ast->sprint;

    eq_or_diff $ast->roundtrip($discardables), $lua_src, qq{$lua_dir/$lua_file};
}

done_testing();
