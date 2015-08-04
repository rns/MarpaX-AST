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
    $parser_module_dir = '../MarpaX-Languages-Lua-AST';
    $parser_module_dir = qq{../$parser_module_dir}
        unless $ENV{HARNESS_ACTIVE};
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

sub reproduce_lua_src{
    my ($ast, $discardables) = @_;

    my $src = '';
    my $visited = {};

    $ast->decorate(
        $discardables,
        sub {
            my ($where, $span_before, $ast, $span_after, $ctx) = @_;
            if ($where eq 'head'){
                $src .= $discardables->span_text($span_before, $visited);
            }
            elsif ($where eq 'tail'){
                $src .= $discardables->span_text($span_after, $visited);
            }
            elsif ($where eq 'node'){
                return unless $ast->is_literal;
                $src .= reverse $discardables->span_text($span_before, $visited);
                $src .= $ast->text;
                $src .= $discardables->span_text($span_after, $visited);
            }
        } );

    return $src;
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

#    warn MarpaX::AST::dumper($ast);
#    warn $ast->sprint;
    my %skip_always = map { $_ => 1 } (
        'statements', 'chunk'
    );

    $ast = $ast->distill({
        root => 'chunk',
        skip => sub {
            my ($ast, $ctx) = @_;
            my ($node_id) = @$ast;
=pod using parent/context to skip nodes
            if ( $node_id eq 'exp' ){
                if (    $ctx->{parent}->id eq 'stat'
                    and $ctx->{parent}->first_child->id eq 'keyword if'){
    #                warn qq{#parent:\n}, $ctx->{parent}->sprint, qq{\n#of\n}, $ast->sprint;
                    return 0;
                }
                else{
                    return 1;
                }
            }
=cut
            return exists $skip_always{ $node_id }
        }
    });

#        warn $ast->sprint;

    eq_or_diff reproduce_lua_src($ast, $discardables), $lua_src, qq{$lua_dir/$lua_file};
}

done_testing();
