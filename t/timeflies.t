#!env perl

# Copyright 2014 Ruslan Shvedov

# json decoding
# based on: https://github.com/jeffreykegler/Marpa--R2/blob/master/cpan/t/sl_timelies.t

use 5.010;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use Marpa::R2;

my $grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),

:default     ::= action => [ name, value ]
lexeme default = action => [ name, value ]

S   ::= NP  VP  period

NP  ::= NN
    |   DT  NN
    |   NN  NNS

VP  ::= VBP NP
    |   VBP PP
    |   VBZ PP

PP  ::= IN  NP

period ~ '.'

:discard ~ whitespace
whitespace ~ [\s]+

DT  ~ 'a' | 'an'
NN  ~ 'arrow' | 'banana'
NNS ~ 'flies'
VBZ ~ 'flies'
NN  ~ 'fruit':i
VBP ~ 'fruit':i
IN  ~ 'like'
VBP ~ 'like'
NN  ~ 'time':i
VBP ~ 'time':i

END_OF_SOURCE
    }
);

my $expected = <<'EOS';
(S
  (NP(NN Time))
  (VP(VBZ flies)
    (PP(IN like)
      (NP(DT an) (NN arrow))))
  (. .))
(S
  (NP(NN Time) (NNS flies))
  (VP(VBP like)
    (NP(DT an) (NN arrow)))
  (. .))
(S
  (NP(NN Fruit))
  (VP(VBZ flies)
    (PP(IN like)
      (NP(DT a) (NN banana))))
  (. .))
(S
  (NP(NN Fruit) (NNS flies))
  (VP(VBP like)
    (NP(DT a) (NN banana)))
  (. .))
EOS

my $paragraph = <<END_OF_PARAGRAPH;
Time flies like an arrow.
Fruit flies like a banana.
END_OF_PARAGRAPH

# structural tags -- need a newline
my %s_tags = map { $_ => undef } qw{ NP VP PP period };

my @actual = ();
for my $sentence (split /\n/, $paragraph){

    my $recce = Marpa::R2::Scanless::R->new( { grammar => $grammar  } );
    $recce->read( \$sentence );

    while ( defined( my $value_ref = $recce->value() ) ) {
        my $value = $value_ref ? bracket ( ${$value_ref} ) : 'No parse';
        push @actual, $value;
    }
}

sub bracket   {

    my ($tag, @contents) = @{ $_[0] };

    state $level++;

    my $bracketed =
        exists $s_tags{$tag} ? ("\n" . ("  " x ($level-1))) : '';

    $tag = '.' if $tag eq 'period';

    if (ref $contents[0]){
        $bracketed .=
                "($tag"
            .   join(' ', map { bracket($_) } @contents)
            .   ")";
    }
    else {
        $bracketed .= "($tag $contents[0])";
    }

    $level--;

    return $bracketed;
}

my $got = join ( "\n", @actual ) . "\n";
$got =~ s{\s+\n}{\n}gms;

eq_or_diff( $got, $expected, 'Ambiguous English sentences' );

done_testing();
