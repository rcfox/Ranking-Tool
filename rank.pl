#!/usr/bin/perl
use 5.012_000;
use strict;
use warnings;
use English;
use Getopt::Long;
use Term::ReadKey;
use Tree::RB;
use YAML qw/LoadFile DumpFile/;

my $open_command = "";
my $answers_file = "answers.yaml";
my $show_tree = 0;
my $show_list = 1;
my $remove_item = 0;
my $help = 0;
GetOptions('open-with=s' => \$open_command,
           'answers=s' => \$answers_file,
           'show-list!' => \$show_list,
           'show-tree' => \$show_tree,
           'remove' => \$remove_item,
           'help' => \$help);

if($open_command eq "") {
	$open_command = "unknown-command";
	if($OSNAME eq 'linux') { # Linux - works on Ubuntu!
		$open_command = "/usr/bin/xdg-open";
	}
	elsif($OSNAME eq 'MSWin32') { # Windows - untested
		$open_command = "cmd /c start";
	}
	elsif($OSNAME eq 'darwin') { # Mac OSX - untested
		$open_command = "open";
	}
}

if($help) {
	say "$0 [OPTION]... [ITEM]...";
	say "Options:";
	say "  --remove\t\tRemove the given items rather than inserting.";
	say "  --open-with=<command>\tChange the program used to preview items. (Default: $open_command)";
	say "  --answers=<file>\tChange the file where answers are saved and loaded. (Default: $answers_file)";
	say "  --show-tree\t\tDisplay the structure of the tree used to rank the items.";
	say "  --noshow-list\t\tDisable the output of the current list of items.";
	exit;
}

my %answers;
if( -e $answers_file ) {
	%answers = %{LoadFile($answers_file)};
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
				$answers{$a}{$node->key} = -1;
				$answers{$node->key}{$a} = 1;
			}
			return -1;
		}
		elsif ($key eq 'n') {
			# Mark everything over this as "better" to prevent random questions when the tree is rebalanced.
			my $it = $tree->rev_iter($b);
			while (my $node = $it->next) {
				$answers{$a}{$node->key} = 1;
				$answers{$node->key}{$a} = -1;
			}
			return 1;
		}
		elsif ($key eq 'a') {
			say "Opening $a";
			system("$open_command $a");
		}
		elsif ($key eq 'b') {
			say "Opening $b";
			system("$open_command $b");
		}
		else {
			say "Please answer with 'y' or 'n'.";
		}
	}
}

for(keys %answers) {
	$tree->put($_);
}

if(!$remove_item) {
	for(@ARGV) {
		if(!exists($answers{$_})) {
			$answers{$_}{$_} = 0;
			$tree->put($_);
		}
	}
} else {
	for(@ARGV) {
		$tree->delete($_);
		delete $answers{$_};
		for my $other (keys %answers) {
			delete $answers{$other}{$_};
		}
	}
}

if($show_list) {
	if($tree->size() == 0) {
		say "Nothing has been ranked yet!";
	} else {
		say "Order so far:";
	}
	
	my $it = $tree->iter;
	while (my $node = $it->next) {
		say $node->key;
	}
}

DumpFile($answers_file,\%answers);

if($show_tree) {
	if($tree->size() > 0) {
		print_tree($tree);
	}
}

sub print_tree {
	use Tree::DAG_Node;
	my $tree = Tree::DAG_Node->lol_to_tree( shift()->root->as_lol );
	local $OUTPUT_FIELD_SEPARATOR = "\n";
	say @{ $tree->draw_ascii_tree };
}
