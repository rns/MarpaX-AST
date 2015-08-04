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

sub ast_decorate{
    my ($ast, $discardables, $callback) = @_;

    my $last_literal_node;

    # discardable head
    my $d_head_id = $discardables->starts(0);
    if (defined $d_head_id){
        my $span = $discardables->span( { start => $d_head_id } );
#            warn @$span;
        $callback->('head', $span, $ast, undef, undef);
    }

    my $opts = {
        visit => sub {
            my ($ast, $ctx) = @_;

#            return unless $ast->is_literal;

            if ( $ast->is_literal ){
                $last_literal_node = $ast
            }

            # get node data
            my ($node_id, $start, $length) = @$ast;
            my $end = $start + $length;

            # see if there is a discardable before
            my $id_before = $discardables->ends($start);
            my $span_before = defined $id_before ?
                $discardables->span( { end => $id_before } ) : undef;

            # see if there is a discardable after
            my $id_after = $discardables->starts($end);
            my $span_after = defined $id_after ?
                $discardables->span( { start => $id_after } ) : undef;

#            warn "# $node_id, $start, $length:\n", $ast->sprint;
            $callback->('node', $span_before, $ast, $span_after, $ctx);
        }
    }; ## opts
    $ast->walk( $opts );

    # discardable tail
    my (undef, $start, $length, undef) = @$last_literal_node;
    my $d_tail_id = $discardables->starts($start + $length);
    if (defined $d_tail_id){
        my $span = $discardables->span( { start => $d_tail_id } );
#            warn @$span;
        $callback->('tail', undef, $ast, $span, { last_literal_node => $last_literal_node });
    }
}

#my $lua_dir = qq{$parser_module_dir/t/MarpaX-Languages-Lua-Parser};
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

    # walk ast and see which nodes have discardables before/after them
    my $src = '';
    my $visited = {};

    ast_decorate(
        $ast, $discardables,
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

                if (defined $span_before){
                    my $span_text = '';
                    for my $span_id (@$span_before){
                        last if exists $visited->{$span_id};
                        $span_text = $discardables->value($span_id) . $span_text;
                        $visited->{$span_id}++;
                    }
                    $src .= $span_text;
                }

                $src .= $ast->text;
                $src .= $discardables->span_text($span_after, $visited);
            }
        } );

    eq_or_diff $src, $lua_src, qq{$lua_dir/$lua_file};
}

done_testing();
