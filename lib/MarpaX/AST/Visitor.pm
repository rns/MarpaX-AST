package MarpaX::AST::Visitor;

use strict;
use warnings;
use 5.010;

use Carp;

# self can used as a scratchpad
sub new {
    my ($class, $opts) = @_;
    bless { }, $_[0]
}

# todo: group nodes -- if visit_group => [ node_id1, node_id2, ... ] is in constructor $opts
# check exists $group->{node} => $visit_group
sub visit{
    my ($self, $ast) = @_;

    my $method = 'visit_' . $ast->id;
    $method = 'generic_visit' unless $self->can( $method );

    state $level = 0;
    state $parent = $ast; # unless $ast is root
#    warn "# $method, $level";
    my $context = { level => $level };
    $level++;
    my $result = $self->$method($ast, $context);
    $level--;
    return $result;
}

sub generic_visit{
}

1;
