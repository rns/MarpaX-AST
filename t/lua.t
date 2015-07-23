#!/usr/bin/perl
# Copyright 2014 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use_ok 'MarpaX::AST';

my $parser_module_dir;
BEGIN{
    $parser_module_dir = '../MarpaX-Languages-Lua-AST/';
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

my $p = MarpaX::Languages::Lua::AST->new;

my $lua_src = slurp_file( qq{$parser_module_dir/t/MarpaX-Languages-Lua-Parser/echo.lua} );
my $ast = $p->parse( $lua_src );

$ast = MarpaX::AST->new( $ast );

#say $ast->sprint;

my %skip_always = map { $_ => 1 } (
    'statements', 'chunk'
);

$ast = $ast->distill({
    root => 'chunk',
    skip => sub {
        my ($ast, $ctx) = @_;
        my ($node_id) = @$ast;
        if ( $node_id eq 'exp' ){
            if (    $ctx->{parent}->id eq 'stat'
                and $ctx->{parent}->first_child->id eq 'keyword if'){
#                say qq{#parent:\n}, $ctx->{parent}->sprint, qq{\n#of\n}, $ast->sprint;
                return 0;
            }
            else{
                return 1;
            }
        }
        return exists $skip_always{ $node_id }
    }
});

say $ast->sprint;


done_testing();
