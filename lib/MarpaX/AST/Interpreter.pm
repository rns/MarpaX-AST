package MarpaX::AST::Interpreter;

use strict;
use warnings;
use 5.010;

use Carp;

sub new{
    my ($class, $opts) = @_;
    my $interp = { %$opts };
    bless $interp, $class;
}

use vars qw($AUTOLOAD);

sub AUTOLOAD{
    my ($interp, $ast) = @_;

    state $level = 0; # ??? once per new

    my $node_id = $ast->id;
    my $package = $interp->{namespace} . '::' . $node_id;
    my $method = (split /::/, $AUTOLOAD)[-1];
    croak "Package $package isn't loaded." unless defined *{$package . '::'};

    $level++;
    my $result = $package->$method($ast, $interp);
    $level--;

    return $result;
}

1;
