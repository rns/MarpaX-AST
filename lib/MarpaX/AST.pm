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

=pod head2
    CHILDREN_START allows putting data between the node id and node values,
    most commonly when using [ name, start, length, value ] as the default action.
    CHILDREN_START must be set to the index, where node’s children start, 3
    in the above case.
=cut

# $ast must be [ $node_id, $child1, child2 ] or [ '#text', 'literal_text' ]
sub new {
    my ($class, $ast, $opts) = @_;

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
    return MarpaX::AST::bless( $ast, $class );
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

# assert options and do_walk()
sub walk{
    my ($ast, $opts ) = @_;

    $ast->assert_options($opts, {
        visit => [ sub{ ref $_[0] eq "CODE" }, "CODE ref" ]
    });
    $opts->{traversal} //= 'preorder';
    $opts->{max_depth} //= 1_000_000;
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

    state $context;
    $context->{depth} = $opts->{depth};

    my $skip = $opts->{skip}->( $ast, $context );

    $opts->{depth}++ unless $skip;

    unless ($opts->{depth} > $opts->{max_depth} or $skip) {
        # todo: set parent and siblings in $context
        $opts->{visit}->( $ast, $context );
    }

    my ($node_id, @children) = ( $ast->[0], @$ast[$CHILDREN_START..$#{$ast}] );

    # don't walk into [ 'name', 'value' ] and bare (nameless) literal nodes
    # and childless nodes
    if ( not $ast->is_literal and @children ){
        # set siblings and parents for context and walk on
        do_walk( $_, $opts  ) for @children;
    }

    $opts->{depth}-- unless $skip;
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
        my $indent = $opts->{indent} x ( $context->{depth} );
        if ( $ast->is_literal ){
            $s .= qq{$indent $node_id '$children[0]'\n};
        }
        else{
            $s .= qq{$indent $node_id\n};
        }
    };

    $ast->walk( $opts );

    return $s;
}

sub distill{
    my ($ast, $opts) = @_;

    my $class = ref $ast;

    my $root = $class->new( [ $opts->{root} //= $ast->id, @$ast[1..$CHILDREN_START-1] ] );
    my $parents = [ $root ];

    # append_literals_as_parents requires code commented # convert childless nodes to bare literals below
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
# todo: $ast->validate()
sub validate{
    my ($ast, $external_schema) = @_;
    state $schema = internalize($external_schema);
    # validate() must warn about non-literal $ast nodes missing from $schema
    # every child of a hash node must validate as hash_item
    # every child of an array node must validate as array_item
    # hash_item node must have exactly two children, the first of which must be a literal
    # array_item node must have exactly two children, the first of which must be a literal
    # or a single child
    # undefs?
    return 1;
}

sub internalize{
    my ($external_schema) = @_;
    # convert array refs to hashes for node id lookup
    while (my ($k, $v) = each %$external_schema){
        my $v_href = {};
        $v_href->{$_} = 1 for @$v;
        $external_schema->{$k} = $v_href;
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

    if ($ast->is_literal){ return $ast->text }
    else{
        my $node_id = $ast->id;
        my $children = $ast->children;
        if (exists $schema->{hash}->{$node_id}){
#            warn "hash: ", $ast->id;
            return { map { $_->do_export($schema) } @$children };
        }
        elsif (exists $schema->{hash_item}->{$node_id}){
#            warn "hash item: ", $ast->id;
            my ($key, $value) = @$children;
            return $key->text => $value->do_export($schema);
        }
        elsif (exists $schema->{array}->{$node_id}){
#            warn "array: ", $ast->sprint;
            my $items = [];
            map {
                my $item = ref($_) ? $_->do_export($schema) : $_;
                # todo: validate $ast according to $schema
                # assuming pre-validation
                # array item is indexed [ $index, $value ]
                if (ref $item eq "HASH") {
#                    warn "indexed array item ", dumper($item);
                    $items->[ $item->{index} ] = $item->{value}
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
                return { index => $index->text, value => $value->do_export($schema) };
            }
            elsif(@$children == 1){
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

package MarpaX::AST::Discardables;

use strict;
use warnings;

use Carp;

=pod Overview

A discardable node (‘discardable’ or ‘node’) is an input span typically
discarded by a parser, e.g. whitespace or comment. For a particular
input span ($start, $end) we need to know if it has a discardable
before or after it, i.e. ending at $start or starting at $end.

Discardables are stored as an array of nodes bless()’able to MarpaX::AST

    [ $node_id, $start, $length, $value ]

contiguous discardable nodes having the same $node_id are merged;
their start’s and length’s are set accordingly

$value is the input span starting at $start and ending at $start + $length

=cut

use constant NODE_ID    => 0;
use constant START      => 1;
use constant LENGTH     => 2;
use constant VALUE      => 3;

sub new{
    my ($class) = @_;
    my $self = {};
    $self->{nodes}  = []; # discardable nodes in the order they’ve been post()'ed
    $self->{starts} = {}; # indices of nodes starting at a certain position
    $self->{ends}   = {}; # indices of nodes ending at a certain position
    bless $self, $class;
    return $self;
}

sub post{
    my ($self, $node_id, $start, $length, $value) = @_;
    push @{ $self->{nodes} }, [ $node_id, $start, $length, $value ];
    my $ix = scalar @{ $self->{nodes} } - 1;
    my $prev_ix     = $ix - 1;
    my $prev_length = $self->length($prev_ix);
    my $prev_start  = $self->start($prev_ix);
    if ( $self->start($ix) == $prev_start + $prev_length ){
        # merge contiguous discardables have the same node_id
        if ($self->node_id($ix) eq $self->node_id($prev_ix)){
#            warn "contiguous discardable $prev_ix, $ix: ", $self->node_id($ix), " at ", $prev_start + $prev_length;
            # merge value’s and length’s
            $self->value($prev_ix, $self->value($prev_ix) . $self->value($ix));
            $self->length($prev_ix, $prev_length + $self->length($ix));
            # remove merged contiguous discardable
            pop @{ $self->{nodes} };
            # update previous discardable’s end
            delete $self->{ends}->{$prev_length};
            $self->{ends}->{$prev_start + $self->length($prev_ix)} = $prev_ix;
            # the new discardable node is now merged
            return $prev_ix;
        }
    }
    $self->{starts}->{$start} = $ix;
    $self->{ends}->{$start + $length} = $ix;
    return $ix;
}

# return discardable at index $ix or undef if there is none
sub get {
    my ($self, $ix) = @_;
    return if $ix > @{ $self->{nodes} } - 1;
    return $self->{nodes}->[$ix];
}

# set value of attribute $ix of discardable $ix, if provided,
# return attribute $ix of discardable $ix
# $ix can be a numeric id or array ref of a discardable node
sub attr {
    my ($self, $ix, $val, $attr_ix) = @_;
    my $discardable = ref $ix eq "ARRAY" ? $ix : $self->{nodes}->[$ix];
    defined $val and $discardable->[$attr_ix] = $val;
    return $discardable->[$attr_ix];
}

sub node_id {
    my ($self, $ix, $new_node_id) = @_;
    $self->attr($ix, $new_node_id, NODE_ID)
}

sub start {
    my ($self, $ix, $new_start) = @_;
    $self->attr($ix, $new_start, START)
}

sub length {
    my ($self, $ix, $new_length) = @_;
    $self->attr($ix, $new_length, LENGTH)
}

sub end {
    my ($self, $ix) = @_;
    $self->start($ix) + $self->length($ix)
}

sub value {
    my ($self, $ix, $new_value) = @_;
    $self->attr($ix, $new_value, VALUE)
}

# returns index of a discardable starting at $pos, undef otherwise
sub starts{
    my ($self, $pos) = @_;
    return $self->{starts}->{$pos};
}

# returns index of a discardable ending at $pos, undef otherwise
sub ends{
    my ($self, $pos) = @_;
    return $self->{ends}->{$pos};
}

# returns a ref to array of indices belonging to a span of contiguous discardables
# starting or ending at $curr_ix or [ $curr_ix ] if no span starts or ends there
# $curr_ix is passes as $opts->{start} or $opts->{end} meaning stepping forwards
# or backwards through the nodes array
sub span{
    my ($self, $opts) = @_;
    # set start and direction (negative $step means backwards)
    my $curr_ix;
    my $step;
    if ( exists $opts->{start} ){
        $curr_ix = $opts->{start};
        $step = 1;
    }
    elsif ( exists $opts->{end} ){
        $curr_ix = $opts->{end};
        $step = -1;
    }
    else{
        croak "start or end id must be defined";
    }
    # form the span
    my $span = [ $curr_ix ];
    my $nodes = $self->{nodes};
    for (
            my $next_ix = $curr_ix + 1;
            my $next_node = $self->{nodes}->[$next_ix];
            $next_ix += $step
        )
    {
#        warn qq{$next_ix, $curr_ix};
#        warn $self->start($next_node);
#        warn $self->end($curr_ix);
        # loop while discardables are contiguous, i.e.
        my $curr_node = $nodes->[$curr_ix];
        if ($step > 0) {
            # if forwards next node starts after the current ends
            last if $next_ix > $curr_ix and
                    $next_node->[START] > $curr_node->[START] + $curr_node->[LENGTH];
        }
        elsif ($step < 0) {
            # if backwards next node ends after the current starts
            last if $next_ix < $curr_ix and
                    $next_node->[START] + $next_node->[LENGTH] < $curr_node->[START];
        }
        push @$span, $next_ix;
        $curr_ix = $next_ix;
    }
    return $span;
}

# returns concatenated texts of discardable nodes in $span
# or empty string if $span is not defined
# if $visited is defined, concatenates until discardable nodes is met again
sub span_text{
    my ($self, $span, $visited) = @_;
    return '' unless defined $span;
    my $defined_visited = defined $visited;
    my $span_text = '';
    for my $discardable_ix (@$span){
        last if $defined_visited and exists $visited->{$discardable_ix};
        $span_text .= $self->value($discardable_ix);
        $visited->{$discardable_ix}++ if $defined_visited;
    }
    return $span_text;
}

package MarpaX::AST::Printer;

use strict;
use warnings;

use Carp;

=pod Overview

todo: Implement vertical, horizontal, indented box model per [1] and [2] considering [3].

[1] http://www.semanticdesigns.com/Products/DMS/DMSPrettyPrinters.html

[2] http://stackoverflow.com/questions/5832412/compiling-an-ast-back-to-source-code/5834775#5834775

[3] Preserving the Documentary Structure of Source Code in Language-based Transformation Tools, http://www.informatik.uni-bremen.de/st/lehre/Arte-fakt/Seminar/papers/16/COM.sun.mlvdv.doc.scam_nov01.paper_pdf.pdf


=cut

1;
