# Copyright 2015 Ruslan Shvedov
package MarpaX::AST;

use 5.010;
use strict;
use warnings;

use Carp;
use Scalar::Util qw{ blessed };

# by default, children start at 1 in @$ast
# todo: make this an instance variable
my $CHILDREN_START = 1;
my $root;

=pod head2
    CHILDREN_START allows putting data between the node id and node values,
    most commonly when using [ name, start, length, value ] as the default action.
    CHILDREN_START must be set to the index, where node’s children start, 3
    in the above case.
=cut

# $ast must be [ $node_id, $child1, child2 ] or [ '#text', 'literal_text' ]
sub new {
    my ($class, $ast, $opts) = @_;

    croak "Arg 1 must be defined" unless defined $ast;
    croak "Arg 1 must be a reference, not $ast" unless ref $ast;

    # change children start index, if set in options
    if (ref $opts eq "HASH"){
        if (exists $opts->{CHILDREN_START}){
            croak "No children at CHILDREN_START $opts->{CHILDREN_START}, " .
                "check ':default ::= action =>' arrays in the grammar"
                    if @$ast < $opts->{CHILDREN_START};
            $CHILDREN_START = $opts->{CHILDREN_START};
        }
    }
#    warn $CHILDREN_START;
    $root = $ast;
    return MarpaX::AST::bless( $ast, $class );
}

# todo: test is_root
sub is_root{
    $_[0] eq $root;
}

sub MarpaX::AST::bless{

    my ($ast, $class) = @_;

    # bless root
    bless $ast, $class;
    # bless descendants
    $ast->walk( {
        visit => sub {
            if ( ref($_[0]) eq "ARRAY" and not blessed($_[0]) ) {
#                warn dumper($_[0]);
                CORE::bless $_[0], $class;
            }
        }
    } );
    $root = $ast;
    return $ast;
}

# set node id if caller provides it, return node id
sub id{
    my ($ast, $id) = @_;
    if (defined $id){
        $ast->[0] = $id;
    }
    return $ast->[0];
}

# return true if node is nulled -- [ 'name', ..., undef ]
sub is_nulled{
    my ($ast) = @_;
    return not defined $ast->first_child;
}

# return true if node is a bare literal: [ '#text', $value ]
sub is_bare_literal{
    my ($ast) = @_;
    return 1 if $ast->id eq '#text';
}

# return true if node is a literal: [ 'name', ..., 'value' ] or bare literal: [ '#text', $value ]
sub is_literal{
    my ($ast) = @_;
    my ($node_id, @children) = ( $ast->[0], @$ast[$CHILDREN_START..$#{$ast}] );
#    warn "is_literal: $node_id, @children", $node_id eq '#text';
    # check for bare literal
    croak "Node id undefined." unless defined $node_id;
    return 1 if $node_id eq '#text';
    # a node is literal if it has ...
    return (
        @children == 1 and          # ... only one child,
        defined $children[0] and    # which is defined,
        not ref $children[0]        # and is a scalar
    );
}

sub descendant{
    my ($ast, $level) = @_;
    $ast = $ast->[$CHILDREN_START] for 1..$level;
    return $ast;
}

# set the child at index $ix if caller provides it,
# if Arg3 is an array ref, use splice
# to expand child at $ix with Arg3's contents
# return the child at index $ix starting at 0
sub child{
    my ($ast, $ix, $child) = @_;
    $ix += $CHILDREN_START unless $ix == -1;
    if (defined $child){
        if (ref $child eq "ARRAY"){
            splice @$ast, $ix, 1, @$child; # replace 1 element with list
        }
        else{
           croak "Child must be a blessed ref, not " . $child unless blessed $child;
           $ast->[$ix] = $child;  # replace 1 element with blessed scalar
        }
    }
    return $ast->[$ix];
}

# set first child if the caller provides it,
# return the first child that matches $predicate if arg 1 is a code ref
sub first_child{
    my ($ast, $child) = @_;
    return $ast->child(0, $child);
}

# shortcut for ->first_child->first_child
sub first_grandchild{
    my ($ast) = @_;
    return $ast->child(0)->child(0);
}

sub second_child{
    my ($ast, $child) = @_;
    return $ast->child(1, $child);
}

# set last child if the caller provides it,
# return the last child that matches $predicate if arg 1 is a code ref
sub last_child{
    my ($ast, $child) = @_;
    return $ast->child(-1, $child);
}

# insert $child at position just before $ix
# return splice() return value
sub insert_before_child{
    my ($ast, $ix, $child) = @_;
    return splice @$ast, $CHILDREN_START + $ix, 0, $child;
}

# append $child to children
# return the last child
sub append_child{
    my ($ast, $child) = @_;

#    warn "# appending child:\n", dumper($child), "\n", "# to ast:\n", dumper($ast);

    if (defined $child){
        croak "Child must be a blessed ref, not " . $child unless blessed $child;
        push @{ $ast }, $child;
    }
    return $ast->[-1];
}

# if $new_children is an array ref, sets $ast children to it and returns newly set children
# if $new_children is a code ref, returns $ast children for which $children->($child) returns 1
# if $new_children is undefined, returns $ast children
# if there no children, returns empty array
sub children{
    my ($ast, $new_children) = @_;
    my ($node, @children) = ( $ast->[0], @$ast[$CHILDREN_START..$#{$ast}] );
    if (defined $new_children){
        if (ref $new_children eq "CODE"){
            my $found = [];
            for my $ix (0..$#children){
                push @$found, $children[$ix] if $new_children->( $children[$ix], $ix );
            }
        }
        elsif (ref $new_children eq "ARRAY") {
            splice @$ast, $CHILDREN_START, @$ast - $CHILDREN_START, @$new_children;
        }
    }
    return \@children;
}

sub children_count{
    my ($ast) = @_;
    return @$ast - $CHILDREN_START;
}

# remove children for which $remove sub returns a true value
sub remove_children{
    my ($ast, $remove) = @_;

    croak "Arg 2 must be defined as a CODE ref." unless defined $remove;
    croak "Arg 2 must be a ref to CODE, not " . ref $remove unless ref $remove eq "CODE";

    my ($node_id, @children) = ( $ast->[0], @$ast[$CHILDREN_START..$#{$ast}] );
    my @new_children;
    for my $child (@children){
        next if $remove->($child);
        push @new_children, $child;
    }
    $ast->children(\@new_children);

    return $ast;
}

# remove child at $ix
# return removed child
sub remove_child{
    my ($ast, $ix) = @_;
    croak "Arg 2 must be defined as an index of the child to be removed." unless defined $ix;
    return splice ( @$ast, $ix + $CHILDREN_START, 1 );
}

sub assert_options{
    my ($ast, $opts, $spec) = @_;

    $spec //= {};
    my $meth = (caller(1))[3];

    $opts //= 'undef';
    croak $meth . ": options must be a HASH ref, not $opts." unless ref $opts eq "HASH";

    for my $opt ( sort keys %{ $spec } ){
        my ($pred, $desc) = @{ $spec->{$opt} };
        croak $meth . ": '$opt' option required." unless exists $opts->{$opt};
        $opts->{$opt} //= 'undef';
        croak qq{$meth: $opt option must be a $desc, not $opts->{$opt}}
            unless $pred->( $opts->{$opt} );
    }

}

my @parents;
my @siblings;

# assert options and do_walk()
sub walk{
    my ($ast, $opts ) = @_;

    undef @parents;
    undef @siblings;

    $ast->assert_options($opts, {
        visit => [ sub{ ref $_[0] eq "CODE" }, "CODE ref" ]
    });
    $opts->{traversal} //= 'preorder';
    $opts->{skip} //= sub { 0 };
    $opts->{depth} = 0;

    return do_walk( $ast, $opts );
}

# Marpa AST node types
# normal                            : [ $node_id, ..., $child1, $child2, ... ]
# lexeme (literal, leaf, terminal)  : [ $node_id, ..., $text ]
# bare literal ('text' in SLIF)     : $text
# nulled                            : [ $node_id, ..., undef ]
sub do_walk{
    my ($ast, $opts ) = @_;

    # check for and skip nulled nodes
    return unless defined $ast;

    # check for and bless bare literal nodes
    if (not ref $ast){
        my $node = [ '#text' ];
        if ($CHILDREN_START > 1){
            push @$node, undef for 1..$CHILDREN_START-1;
#            carp $CHILDREN_START - 1, " undef's are inserted between node id and first child at $CHILDREN_START";
#            warn dumper($ast);
        }
        push @$node, $ast;
        $ast = CORE::bless $node, __PACKAGE__ ;
    }

    my ($node_id, @children) = ( $ast->[0], @$ast[$CHILDREN_START..$#{$ast}] );

    state $context;
    $context->{depth} = $opts->{depth};
    # todo: do we need grand, grand ... parents?
    $context->{ascendants} = \@parents;
    $context->{parent} = $parents[ $context->{depth} - 1 ];
    $context->{siblings} = $siblings[ $context->{depth} - 1 ];

    my $skip = $opts->{skip}->( $ast, $context );

    # set depth, siblings and parents for $context
    unless ($skip){
        $opts->{depth}++ ;
        push @parents, $ast;
        push @siblings, \@children;
    }

    # do visit
    if (not $skip) {
        $opts->{visit}->( $ast, $context );
    }

    # don't walk into [ 'name', 'value' ], bare (nameless) literal nodes
    # and childless nodes
    if ( not $ast->is_literal and @children ){
        do_walk( $_, $opts  ) for @children;
    }

    # unset depth, siblings and parents for $context
    unless ($skip){
        $opts->{depth}--;
        pop @parents;
        pop @siblings;
    }
}

sub text{
    my ($ast) = @_;
    return $ast->first_child;
}

sub sprint{
    my ($ast, $opts ) = @_;

    my $s = '';

    $opts //= { };
    $ast->assert_options( $opts, { } );
    $opts->{indent} = '  ';

    # set visitor
    $opts->{visit} = sub {
        my ($ast, $context) = @_;
        my ($node_id, @children) = ( $ast->[0], @$ast[$CHILDREN_START..$#{$ast}] );
        croak "Node id undefined." if not defined $node_id;
        croak "Bad node id: $node_id, not scalar." if ref $node_id;
        my $indent = $opts->{indent} x ( $context->{depth} );
        if ( $ast->is_literal ){
            $s .= qq{$indent$node_id '$children[0]'\n};
        }
        else{
            $s .= qq{$indent$node_id\n};
        }
    };

    $ast->walk( $opts );

    return $s;
}

sub distill{
    my ($ast, $opts) = @_;

    my $class = ref $ast;

    # duplicate root (unless another root id defined in $opts) and set it as first parent
    my $root_id = $ast->id;
    my $root = $class->new( [ $opts->{root} //= $root_id, @$ast[1..$CHILDREN_START-1] ] );
    my $parents = [ $root ];

    # append_literals_as_parents requires code
    # commented below as '# convert childless nodes to bare literals '
    $opts->{append_literals_as_parents} //= 0;
    if (ref $opts->{append_literals_as_parents} eq "ARRAY"){
        $opts->{append_literals_as_parents} = { map { $_ => 1 } @{ $opts->{append_literals_as_parents} } }
    };

    $ast->walk( {
        skip =>
            ref $opts->{skip} eq 'ARRAY' ? sub {
                my ($ast) = @_;
                my ($node_id) = @$ast;
                state $skip = { map { $_ => 1 } @{ $opts->{skip} } };
                return exists $skip->{ $node_id }
            } : $opts->{skip},
        visit => sub {
            my ($ast, $ctx) = @_;
            my ($node_id, @children) = ( $ast->[0], @$ast[$CHILDREN_START..$#{$ast}] );

            state $dont_visit = { map { $_ => 1 } @{ $opts->{dont_visit} } };
            state $dont_visit_ix = keys %$dont_visit;

            # todo: document or remove print_node
            $opts->{print_node}->($ast, $ctx) if exists $opts->{print_node};

            return if exists $dont_visit->{ $node_id };

            my $parent_ix = $ctx->{depth} - $dont_visit_ix;

            my $child_to_append;
            if ($ast->is_literal()){
                # append only some literals as parents
                if (ref $opts->{append_literals_as_parents} eq "HASH"){
                    # append this literal as parent
                    if (exists $opts->{append_literals_as_parents}->{$node_id}){
                        $child_to_append = [ $children[0], @$ast[1..$CHILDREN_START-1] ];
                    }
                    # append this literal as child
                    else{
                        $child_to_append = $ast;
                    }
                }
                # append all literals as parents
                elsif ($opts->{append_literals_as_parents}){
#                    warn "as parent: $node_id";
                    $child_to_append = [ $children[0], @$ast[1..$CHILDREN_START-1] ]
                }
                # append all literals as children
                else{
                    $child_to_append = $ast;
                }
            }
            else{
                $child_to_append = [ $node_id, @$ast[1..$CHILDREN_START-1] ]
            }

            return unless defined $parents->[ $parent_ix ];

            $parents->[ $parent_ix + 1 ] =
                $parents->[ $parent_ix ]->append_child(
                    $class->new( $child_to_append ) );

        }
    } );

    # convert childless nodes to bare literals
    if ($opts->{append_literals_as_parents}){
        $root->walk({ visit => sub {
            my ($ast, $ctx) = @_;
            return if $ast->is_literal;
            my @children = @{ $ast->children };
            for my $ix (0..@children){
                my $child = $children[$ix];
                next unless defined $child;
                unless (@{ $child->children }){
#                    warn "childless child: ", $child->id, " of parent ", $ast->id;
                    # set childless node as bare literal
                    my $bare_literal = [ '#text' ];
                    push @$bare_literal, $child->[$_] for 1..$CHILDREN_START-1;
                    push @$bare_literal, $child->id;
                    $ast->[$CHILDREN_START + $ix] = __PACKAGE__->new($bare_literal);
#                    warn $ast->sprint;
                }
            }
        } });
    }

    # check if we have duplicated root and fix it
    if (
        $root->id eq $ast->id and
        $root->children_count == 1 and
        $root->first_child->id eq $root_id
    ){
        $root = $root->first_child
    }

    return $root;
}

# walk $ast, checking if spans of discardable nodes in $discardables
# occur before after an ast node and call $callback on such spans,
# ast node and context. The callback can insert discardable nodes
# in $ast or concatenate them to literal nodes. A hash can be used
# to avoid duplicate visits, if needed.
sub decorate{
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

            if ( $ast->is_literal ){
                $last_literal_node = $ast
            }

            # get node data
            my ($node_id, $node_text_start, $node_text_length) = @$ast;
            my $node_text_end = $node_text_start + $node_text_length;

            # see if there is a discardable before
            my $id_before = $discardables->ends($node_text_start);
            my $span_before = defined $id_before ?
                $discardables->span( { end => $id_before } ) : undef;

            # see if there is a discardable after
            my $id_after = $discardables->starts($node_text_end);
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

# reproduces the exact source text using $discardables
sub roundtrip{
    my ($ast, $discardables) = @_;

    my $source = '';
    my $visited = {};

    $ast->decorate(
        $discardables,
        sub {
            my ($where, $span_before, $ast, $span_after, $ctx) = @_;
            if ($where eq 'head'){
                $source .= $discardables->span_text($span_before, $visited);
            }
            elsif ($where eq 'tail'){
                $source .= $discardables->span_text($span_after, $visited);
            }
            elsif ($where eq 'node'){
                return unless $ast->is_literal;
                $source .= $discardables->span_text($span_before, $visited);
                $source .= $ast->text;
                $source .= $discardables->span_text($span_after, $visited);
            }
        } );

    return $source;
}

# returns for debugging if smth. goes wrong
# todo: $ast->validate() validate $ast according to $schema
sub validate{
    my ($ast, $external_schema) = @_;
    state $schema = internalize($external_schema);
    # validate() must warn about non-literal $ast nodes missing from $schema
    # every child of a hash node must (1) appear as hash_item in the scheme and (2) validate as hash_item
    # the children_count of hash nodes (except hash_item nodes) must be even
    # every child of an array node must validate as array_item
    # hash_item node must have exactly two children, the first of which must be a literal
    # array_item node must have exactly two children, the first of which must be a literal
    # name_array node must have exactly two children, the first of which must be a literal
    # "must be a literal" above includes "export()'able to literal"
    return 1;
}

sub internalize{
    my ($external_schema) = @_;
    # convert array refs to hashes for node id lookup
    while (my ($k, $v) = each %$external_schema){
        my $v_href = {};
        if (ref $v eq "ARRAY"){
            $v_href->{$_} = 1 for @$v;
            $external_schema->{$k} = $v_href;
        }
    }
#    warn "# internal schema:\n", dumper($external_schema);
    return $external_schema;
}

sub export{
    my ($ast, $external_schema) = @_;
    return $ast->do_export(internalize($external_schema));
}

sub do_export{
    my ($ast, $schema) = @_;

    my $node_id = $ast->id;
    if ($ast->is_literal){
        my $text = $ast->text;
#        warn qq{$node_id, $text, $schema->{$node_id}};
        # process literal text based on its node id
        if ( exists $schema->{$node_id} ) { # can be false or undef (e.g., json)
            my $node_id_proc = $schema->{$node_id};
            return $node_id_proc->($text) if ref $node_id_proc eq "CODE";
            # constant
#            warn q{constant};
            return $schema->{$node_id};
        }
        # no text processing
        return $text;
    }
    else{
        my $children = $ast->children;
        if (exists $schema->{hash}->{$node_id}){
#            warn "hash: ", $ast->id;
            return { map { $_->do_export($schema) } @$children };
        }
        elsif (exists $schema->{hash_item}->{$node_id}){
#            warn "hash item: ", $ast->id;
            my ($key, $value) = @$children;
            return $key->do_export($schema) => $value->do_export($schema);
        }
        elsif (exists $schema->{array}->{$node_id}){
#            warn "array: ", $ast->sprint;
            my $items = [];
            map {
                my $item = ref($_) ? $_->do_export($schema) : $_;
                # array item is indexed
                if (ref $item eq "HASH" and my $indexed_array_item = $item->{'indexed array item'}) {
#                    warn "indexed array item ", dumper($item);
                    $items->[ $indexed_array_item->{index} ] = $indexed_array_item->{value}
                }
                # array item is bare (scalar)
                else {
#                    warn "unindexed array item ", dumper($item);
                    push @$items, $item
                }
            } @$children;
            return $items;
        }
        elsif (exists $schema->{named_array}->{$node_id}){
            $schema->{array}->{$node_id} = 1;
            return [ $ast->id, [ map { $_->do_export($schema) } @$children ] ];
        }
        elsif (exists $schema->{array_item}->{$node_id}){
#            warn "array item: ", $ast->sprint;
            if (@$children == 2){
#                warn "indexed array item";
                my ($index, $value) = @$children;
                return { 'indexed array item' =>
                    { index => $index->do_export($schema), value => $value->do_export($schema) }
                    };
            }
            elsif (@$children == 1){
                return $children->[0]->do_export($schema);
            }
        }
        else{ return $_->do_export($schema) for @$children }
    }
}

sub dumper{
  use Data::Dumper;
  {
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 1;
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Deparse = 1;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Deepcopy = 1;
    return Dumper(@_);
  }
}

1;
