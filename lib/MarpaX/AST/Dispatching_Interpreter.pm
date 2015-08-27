# Copyright 2015 Ruslan Shvedov
package MarpaX::AST::Dispatching_Interpreter;

use 5.010;
use strict;
use warnings;

use Carp;

# main:: is the default namespace
sub new{
    my ($class, $opts) = @_;

    croak "Arg 1 must be an HASH ref, not $opts." if defined $opts and not ref $opts eq "HASH";

    my $interpreter = { %$opts } if defined $opts;
    $interpreter->{namespace} //= 'main';
    $interpreter->{context} //= {};
    # get namespace specification(s)
    my $namespace_spec = {};
    for my $namespace
    (
        # we need only namespaces for nodes
        grep { $_ ne 'context' and $_ ne 'namespace' } keys %{ $opts }
    ){
        my $node_spec = $opts->{$namespace};
        if (ref $node_spec eq "ARRAY"){
            for my $node_id ( @{$node_spec} ){
                $namespace_spec->{node_ids}->{$node_id} = $namespace;
            }
        }
        elsif (ref $node_spec eq "CODE"){
            $namespace_spec->{namespaces}->{$namespace} = $node_spec;
        }
        else{
            croak "Node list specifier must by an ARRAY or a CODE ref, not $node_spec.";
        }
    }
    $interpreter->{namespace_spec} = $namespace_spec;

    bless $interpreter, $class;
}

sub context{ $_[0]->{context}  or croak "Interpreter context nod defined." }
sub ctx { $_[0]->{context} or croak "Interpreter context nod defined." }

use vars qw($AUTOLOAD);

sub AUTOLOAD{
    my ($interpreter, $ast, @tail) = @_;

    croak "Interpreter undefined" unless defined $interpreter;
    croak "Arg 1 must be an instance of " . __PACKAGE__ . ", not $interpreter."
        unless $interpreter->isa(__PACKAGE__);

    croak "AST undefined" unless defined $ast;
    croak "Arg 2 must be an instance of MarpaX::AST, not $ast."
        unless $ast->isa('MarpaX::AST');

#    warn "# autoload: ", $AUTOLOAD unless $AUTOLOAD =~ m{cmpt$};

    state $level = 0; # todo: check if $ast is root?
    my $context = $interpreter->{context};
    $context->{level} = $level;

    my $node_id = $ast->id;

#    warn MarpaX::AST::dumper($interpreter->{namespace_spec}, $node_id);
    my $package;
    # check namespace spec
    if (my $namespace_by_node = $interpreter->{namespace_spec}->{node_ids}->{$node_id}){
#        warn "by node";
        $package = $namespace_by_node;
    }
    # first namespace, whose predicate returns true, will be used
    elsif (my $namespaces = $interpreter->{namespace_spec}->{namespaces}){
#        warn "by predicate";
        for my $namespace_by_predicate (keys %{$namespaces}){
            my $pred = $namespaces->{$namespace_by_predicate};
            if ( $pred->($ast) ){
                $package = $namespace_by_predicate;
            }
        }
    }

    # default package
    $package //= $interpreter->{namespace} . '::' . $node_id;
    croak "Package $package isn’t loaded." unless defined *{$package . '::'};
#    warn $package;

    my $method = (split /::/, $AUTOLOAD)[-1];
    croak "Method $method not defined in package $package." unless $package->can($method);
#    warn $method;

    $level++;
    my $result = $package->$method($interpreter, $ast, @tail);
    $level--;

    return $result;
}

# required to avoid errors "in cleanup" under some perls
# see http://www.perlmonks.org/bare/?node_id=93037
sub DESTROY { }

1;
