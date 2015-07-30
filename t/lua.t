#!/usr/bin/perl
# Copyright 2015 Ruslan Shvedov

use 5.010;
use strict;
use warnings;

use Test::More;

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

#my $lua_dir = qq{$parser_module_dir/t/MarpaX-Languages-Lua-Parser};
#my $lua_dir = qq{$parser_module_dir/t/lua5.1-tests};
my $lua_dir = $ENV{HARNESS_ACTIVE} ?  't' : '.';

for my $lua_file (qw{ corner_cases.lua }){
    my $lua_src = slurp_file( qq{$lua_dir/$lua_file} );
    my $p = MarpaX::Languages::Lua::AST->new;

    my @ast = $p->parse( $lua_src );

    for my $ast (@ast){
        #$ast = MarpaX::AST->new( $ast );
        $ast = MarpaX::AST->new( $$ast, { CHILDREN_START => 3 } );

        #say $ast->sprint;

        my %skip_always = map { $_ => 1 } (
            'statements', 'chunk'
        );

        $ast = $ast->distill({
            root => 'chunk',
            skip => sub {
                my ($ast, $ctx) = @_;
                my ($node_id) = @$ast;
=pod
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
=cut
                return exists $skip_always{ $node_id }
            }
        });

        say $ast->sprint;
    }
}

done_testing();
