package MarpaX::AST::Interpreter;

use strict;
use warnings;
use 5.010;

use Carp;

sub new {
    my ($class, $ast, $opts) = @_;
    my $interpreter = {};
    $interpreter->{prefix} = $opts->{prefix} // 'My::Interpreter';
    $interpreter->{skip} = { map { $_ => 1 } @{ $opts->{skip} // [] } };
    # bless $ast nodes to qq{$interpreter->{prefix}::$node_id}

    # bless descendants
    $ast->walk( {
        visit => sub {
            my ($ast) = @_;
            return if exists $interpreter->{skip}->{$ast->id};
            if ( ref $ast ) {
                my $class = $interpreter->{prefix} . '::' . $ast->id;
                croak "Package $class doesn't exist." unless defined *{$class . '::'};
                CORE::bless $_[0], $class;
            }
        }
    } );
    bless $ast, $interpreter->{prefix} . '::' . $ast->[0];
    $interpreter->{ast} = $ast;
    bless $interpreter, $class;
}

sub ast { $_[0]->{ast} }

1;
