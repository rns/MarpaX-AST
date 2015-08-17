package MarpaX::AST::Visitor;

use strict;
use warnings;
use 5.010;

use Carp;

# self can used as a scratchpad
sub new { bless { }, $_[0] }

sub visit{
    my ($self, $ast) = @_;
    my $method = 'visit_' . $ast->id;
#    warn "# $method ";
    if ( $self->can( $method ) ){
        return $self->$method($ast);
    }
    else{
        return $self->generic_visit($ast);
    }
}

sub generic_visit{
}

1;
