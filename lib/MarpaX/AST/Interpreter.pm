package MarpaX::AST::Interpreter;

use strict;
use warnings;
use 5.010;

use Carp;

sub new{
    my ($class, $opts) = @_;
    my $interpreter = { %$opts } if defined $opts;
    $interpreter->{namespace} //= 'main';
    $interpreter->{context} //= {};
    # if an opt contains ::, it must be a namespace for a list of nodes
    my $namespace_spec = {};
    for my $namespace
    (
        grep { $_ ne 'context' and $_ ne 'namespace' and index '::', 0 >= 0 }
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
            croak "Node specifier must by an ARRAY or a CODE ref, not $node_spec.";
        }
    }
    $interpreter->{namespace_spec} = $namespace_spec;
    bless $interpreter, $class;
}

sub context{ $_[0]->{context} }
sub ctx { $_[0]->{context} }

use vars qw($AUTOLOAD);

sub AUTOLOAD{
    my ($interpreter, $ast, @tail) = @_;
    croak "Arg 1 must be a MarpaX::AST::Interpreter, not $interpreter." unless $interpreter->isa('MarpaX::AST::Interpreter');
    croak "Arg 2 must be a MarpaX::AST, not $ast." unless $ast->isa('MarpaX::AST');

#    warn $AUTOLOAD;

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
    # first namespace whose predicate returns true will be used
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
    croak "Package $package isn't loaded." unless defined *{$package . '::'};

#    warn $package;

    my $method = (split /::/, $AUTOLOAD)[-1];
    croak "Method $method not defined in package $package." unless $package->can($method);

#    warn $method;

    $level++;
    my $result = $package->$method($interpreter, $ast, @tail);
    $level--;

    return $result;
}

1;
