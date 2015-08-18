package MarpaX::AST::Interpreter;

use strict;
use warnings;
use 5.010;

use Carp;

sub new {
    my ($class, $ast, $opts) = @_;

    my $interpreter = {};

    $interpreter->{namespace} = $opts->{namespace} // 'My::Interpreter';
    for my $opt (qw{skip bless}){
        if (my $node_spec = $opts->{$opt}){
            if (ref $node_spec eq "ARRAY"){
                $interpreter->{$opt} = { map { $_ => 1 } @{ $node_spec } };
            }
            else{
                croak "$opt must be a ref to ARRAY, not $node_spec.";
            }
        }
    }

    # bless nodes
    $ast->walk( {
        visit => sub {
            my ($ast) = @_;
            my $node_id = $ast->id;

            if (my $bless_nodes = $interpreter->{bless}){
                return unless exists $bless_nodes->{$node_id};
            }

            if (my $skip_nodes = $interpreter->{skip}){
                return if exists $skip_nodes->{$node_id};
            }

            # only valid package name characters are allowed
            $node_id =~ tr/ /_/;

            if ( ref $ast ) {
                my $class = $interpreter->{namespace} . '::' . $node_id;
                croak "Package $class doesn't exist." unless defined *{$class . '::'};
                CORE::bless $_[0], $class;
            }
        }
    } );
    bless $ast, $interpreter->{namespace} . '::' . $ast->[0];
    $interpreter->{ast} = $ast;
    bless $interpreter, $class;
}

sub ast { $_[0]->{ast} }

1;
