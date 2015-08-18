package MarpaX::AST::Visitor;

use strict;
use warnings;
use 5.010;

use Carp;

=pod

    $opts can map a method name to

        (1) node IDs ARRAY ref -- method will called
            for nodes with the specified IDs

        (2) predicate CODE ref -- method will be called
            if predicate returns true for the node

=cut

sub new {
    my ($class, $opts) = @_;
    my $visitor = {};
    my $method_spec = {};
    while ( my ($method, $node_spec) = each %{$opts} ){
#        warn $method, $node_spec;
        if (ref $node_spec eq "ARRAY"){
            for my $node_id ( @{$node_spec} ){
                $method_spec->{node_ids}->{$node_id} = $method;
            }
        }
        elsif (ref $node_spec eq "CODE"){
            $method_spec->{methods}->{$method} = $node_spec;
        }
        else{
            croak "Node specifier of $method method must be an ARRAY or CODE ref, not $node_spec.";
        }
    }
    $visitor->{method_spec} = $method_spec;
    bless $visitor, $class;
}

sub visit{
    my ($visitor, $ast) = @_;

#    warn "# visiting:\n", $ast->sprint;
    my $node_id = $ast->id;

    my $method;
    # check method spec
    if (my $method_by_node = $visitor->{method_spec}->{node_ids}->{$node_id}){
#        warn "by code";
        $method = $method_by_node;
    }
    # first method, whose predicate returns true will be used
    elsif (my $methods = $visitor->{method_spec}->{methods}){
#        warn "by predicate";
        for my $method_by_predicate (keys %{$methods}){
            my $pred = $methods->{$method_by_predicate};
            if ( $pred->($ast) ){
                $method = $method_by_predicate;
            }
        }
    }
    # default visitor
    $method //= 'visit_' . $node_id;
    $method = 'generic_visit' unless $visitor->can( $method );

#    warn $method;

    state $level = 0;
#    warn "# $method, $level";
    my $context = { level => $level };
    $level++;
    my $result = $visitor->$method($ast, $context);
    $level--;
    return $result;
}

sub generic_visit{
    croak "generic_visit() needs to be unimplemented";
}

1;
