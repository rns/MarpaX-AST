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

#my $lua_dir = qq{$parser_module_dir/t/MarpaX-Languages-Lua-Parser};
#my @lua_files = qw{ echo.lua };

#my $lua_dir = qq{$parser_module_dir/t/lua5.1-tests};
#my @lua_files = qw{ constructs.lua };

my $lua_dir = $ENV{HARNESS_ACTIVE} ?  't' : '.';
my @lua_files = qw{ corner_cases.lua };

sub ast_decorate{
    my ($ast, $discardables, $call) = @_;

    my $last_literal_node;

    # discardable head
    my $d_head_id = $discardables->starts(0);
    if (defined $d_head_id){
        my $span = $discardables->span( { start => $d_head_id } );
#            warn @$span;
        $call->('head', $span, $ast);
    }

    my $opts = {
        visit => sub {
            my ($ast, $ctx) = @_;

            return unless $ast->is_literal;

            $last_literal_node = $ast;

            my ($node_id, $start, $length) = @$ast;

            # see if there is a discardable before
            my $id_before = $discardables->ends($start);
            if ( defined $id_before ){
                my $span = $discardables->span( { end => $id_before } );
#                    warn "before: ", @$span;
                $call->('before', $span, $ast, $ctx);
            }

            $call->('node', undef, $ast, $ctx);
            warn "$node_id, $start, $length, ", $ast->text;
#                warn qq{node_text: '$node_text'};

            # see if there is a discardable after
            my $end = $start + $length;
            my $id_after = $discardables->starts($end);
            if ( defined $id_after ){
                my $span = $discardables->span( { start => $id_after } );
#                    warn @$span;
                $call->('after', $span, $ast, $ctx);
            }

        }
    }; ## opts
    $ast->walk( $opts );

    # discardable tail
    my (undef, $start, $length, undef) = @$last_literal_node;
    my $d_tail_id = $discardables->starts($start + $length);
    if (defined $d_tail_id){
        my $span = $discardables->span( { start => $d_tail_id } );
#            warn @$span;
        $call->('tail', $span, $ast);
    }
}

for my $lua_file (@lua_files){
    my $lua_src = slurp_file( qq{$lua_dir/$lua_file} );
    my $p = MarpaX::Languages::Lua::AST->new;

    my $ast = $p->parse( $lua_src );
    warn MarpaX::AST::dumper($p->{discardables});
    my $discardables = $p->{discardables};

    $ast = MarpaX::AST->new( $ast, { CHILDREN_START => 3 } );

#        warn MarpaX::AST::dumper($ast);
    warn $ast->sprint;
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

    ast_decorate($ast, $discardables, sub {
        my ($where, $span, $ast, $ctx) = @_;
        if ($where eq 'head'){
            for my $span_id (@$span){
                return if exists $visited->{$span_id};
                $src .= $discardables->value($span_id);
                $visited->{$span_id}++;
            }
        }
        elsif ($where eq 'before'){
            my $node_text = '';
            for my $span_id (@$span){
                return if exists $visited->{$span_id};
                $node_text = $discardables->value($span_id) . $node_text;
                $visited->{$span_id}++;
            }
            $src .= $node_text;
        }
        elsif ($where eq 'after'){
            my $node_text = '';
            for my $span_id (@$span){
                return if exists $visited->{$span_id};
                $node_text .= $discardables->value($span_id);
                $visited->{$span_id}++;
            }
            $src .= $node_text;
        }
        elsif ($where eq 'tail'){
            for my $span_id (@$span){
                return if exists $visited->{$span_id};
                $src .= $discardables->value($span_id);
                $visited->{$span_id}++;
            }
        }
        elsif ($where eq 'node'){
            $src .= $ast->text;
        }
    } );

    eq_or_diff $src, $lua_src, qq{$lua_dir/$lua_file};
}

done_testing();
