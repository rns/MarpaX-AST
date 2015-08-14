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

1;
