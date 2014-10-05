package MarpaX::AST;

use 5.010;
use strict;
use warnings;

use YAML;

use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;
$Data::Dumper::Deepcopy = 1;

use Marpa::R2;

sub new {
    my ($class, $asf) = @_;
    my $self = {};
    bless $self, $class;
}

1;
