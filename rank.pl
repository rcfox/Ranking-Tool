#!/usr/bin/perl
use 5.012_000;
use strict;
use warnings;
use Term::ReadKey;
use Tree::RB;
use YAML qw/LoadFile DumpFile/;

my %answers;
if( -e "answers.yaml" ) {
	%answers = %{LoadFile("answers.yaml")};
}

my $tree = Tree::RB->new(\&ask_comparator);

sub ask_comparator
{
	my ($a,$b) = @_;
	return 0 if($a eq $b);

	if (exists($answers{$a}{$b})) {
		return $answers{$a}{$b};
	}
	
	say "Is $a better than $b?";
	say "Press 'a' to preview $a.";
	say "Press 'b' to preview $b.";
	
	my $key = "";
	while ($key ne 'y' or $key ne 'n') {
		$key = ReadLine(0);
		$key = substr($key,0,1);

		if ($key eq 'y') {
			# Mark everything under this as "not-better" to prevent random questions when the tree is rebalanced.
			my $it = $tree->iter($b);
			while (my $node = $it->next) {
				say $node->key;
				$answers{$a}{$node->key} = -1;
				$answers{$node->key}{$a} = 1;
			}
			return -1;
		}
		elsif ($key eq 'n') {
			# Mark everything over this as "better" to prevent random questions when the tree is rebalanced.
			my $it = $tree->rev_iter($b);
			while (my $node = $it->next) {
				say $node->key;
				$answers{$a}{$node->key} = 1;
				$answers{$node->key}{$a} = -1;
			}
			return 1;
		}
		elsif ($key eq 'a') {
			say "Opening $a";
			system("xdg-open $a 2> /dev/null");
		}
		elsif ($key eq 'b') {
			say "Opening $b";
			system("xdg-open $b 2> /dev/null");
		}
		else {
			say "Please answer with 'y' or 'n'.";
		}
	}
}

for(keys %answers) {
	$tree->put($_);
}

for(@ARGV) {
	if(!exists($answers{$_})) {
		$answers{$_}{$_} = 0;
		$tree->put($_);
	}
}

if($tree->size() == 0) {
	say "Nothing has been ranked yet!";
} else {
	say "Order so far:";
}

my $it = $tree->iter;
while (my $node = $it->next)
{
	say $node->key;
}

DumpFile("answers.yaml",\%answers);