package MarpaX::AST::Interpreter;

use strict;
use warnings;
use 5.010;

use Carp;

sub new{
    my ($class, $opts) = @_;
    my $interp = { %$opts } if defined $opts;
    $interp->{namespace} //= 'main';
    $interp->{context} //= {};
    bless $interp, $class;
}

sub context{ $_[0]->{context} }
sub ctx { $_[0]->{context} }

use vars qw($AUTOLOAD);

sub AUTOLOAD{
    my ($interp, $ast, @tail) = @_;

    state $level = 0; # ??? once per new
    my $context = $interp->{context};
    $context->{level} = $level;

    my $node_id = $ast->id;
    my $package = $interp->{namespace} . '::' . $node_id;
    my $method = (split /::/, $AUTOLOAD)[-1];
    croak "Package $package isn't loaded." unless defined *{$package . '::'};

    $level++;
    my $result = $package->$method($interp, $ast, @tail);
    $level--;

    return $result;
}

1;
