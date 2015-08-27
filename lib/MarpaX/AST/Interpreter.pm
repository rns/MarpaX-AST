# Copyright 2015 Ruslan Shvedov
# todo: better names for both interpreter types
# inheritance-based interpreter doesn't allow to set context
package MarpaX::AST::Interpreter;

use strict;
use warnings;
use 5.010;

use Carp;
use Scalar::Util qw(blessed);

sub new {
    my ($class, $ast, $opts) = @_;

    croak "Arg 1 must be a blessed ref, not $ast." unless blessed $ast;
    croak "Arg 1 must be an instance of MarpaX::AST, not $ast." unless $ast->isa('MarpaX::AST');
    croak "Arg 2 must be an HASH ref, not $opts." if defined $opts and not ref $opts eq "HASH";

    my $interpreter = {};
    $interpreter->{namespace} = $opts->{namespace};
    $interpreter->{skip} = { map { $_ => 1 } @{ $opts->{skip} // [] } };

    # check if the namespace is specified by node list or predicate
    my $namespace_spec = {};
    for my $namespace
    (
        grep { $_ ne 'skip' and $_ ne 'namespace' and index '::', 0 >= 0 }
            keys %{ $opts }
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

    # bless descendants
    $ast->walk( {
        visit => sub {
            my ($ast) = @_;
            return if exists $interpreter->{skip}->{$ast->id};
            if ( ref $ast ) {
                # find class to bless the node in $ast to
                my $class;
                my $node_id = $ast->id;
                # check namespace spec
                if (my $namespace_by_node = $interpreter->{namespace_spec}->{node_ids}->{$node_id}){
            #        warn "by node";
                    $class = $namespace_by_node;
                }
                # first namespace, whose predicate returns true, will be used
                elsif (my $namespaces = $interpreter->{namespace_spec}->{namespaces}){
            #        warn "by predicate";
                    for my $namespace_by_predicate (keys %{$namespaces}){
                        my $pred = $namespaces->{$namespace_by_predicate};
                        if ( $pred->($ast) ){
                            $class = $namespace_by_predicate;
                        }
                    }
                }
                # default class
                croak "Base namespace for nodes must be defined in the constructor" unless defined $interpreter->{namespace};
                $class //= $interpreter->{namespace} . '::' . $node_id;
#                warn $node_id, ', ', $class;

                # check $class and bless the node in $ast to it
                croak "Package $class doesn't exist." unless defined *{$class . '::'};
                croak "Package $class isn't a MarpaX::AST." unless $class->isa('MarpaX::AST');
                CORE::bless $ast, $class;
            }
        }
    } );
    $interpreter->{ast} = $ast;
    bless $interpreter, $class;
}

sub ast { $_[0]->{ast} }

1;
