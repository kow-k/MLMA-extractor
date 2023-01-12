#!/usr/bin/env perl -w

# developed by Kow Kuroda
# contact: kow.kuroda@gmail.com
# created on 2022/12/11
# modifications:
# on 2022/12/12; code refactored by elaborating generates(...) to work.
# on 2022/12/13;
# 1) modified generate(...) to handle recursion properly;
# 2) extended to process grouping using { and }, and ( and ).
# 3) added handling of comment lines starting with # or %
# 4) added options for mode selection among A, B, C and D
# on 2022/12/20; fixed a bug on @pool handling
# on 2023/01/12; added handling of inline comment
#
# This Perl script takes a file and performes dual-mode parsing linewise where
# each line is parsed for components between group opener and closer.
# The valid opener-closer pairs are the following four:
# '[' and ']', '<' and '>', '{' and '}', and '(' and ')'.

use strict ;
use warnings ;
use List::Util qw(min max) ;
use List::MoreUtils qw(any) ;
use Data::Dump qw(dump) ;
#use Data::Dumper ;
#use feature qw(say) ;
#use experimental 'smartmatch' ;
use utf8 ;
use open IO => ":utf8" ;
my $enc = "utf8" ;
#use open IO => ":$enc" ; # doesn't work
binmode STDIN, ":$enc" ;
binmode STDOUT, ":$enc" ;
binmode STDERR, ":$enc" ;

# handle options
use Getopt::Long ;
my %args = ( debug => 0, verbose => 0 ) ;
GetOptions(\%args,
	"help|h",      #print help
	"debug",       #debug option
	"verbose|v",   #verbose option
	"summarize|s", #summarization option
	"greedy|g",    #runs in greedy mode
	"onlyA|A",     #select A grouping only
	"onlyB|B",     #select B grouping only
	"onlyC|C",     #select C grouping only
	"onlyD|D"      #select D grouping only
);
print_help() if $args{help} ;

## variables
my $i ;                # counter
my $Aopener = "[" ;   # opener of a phrase in A mode
my $Acloser = "]" ;   # closer of a phrase in A mode
my $Bopener = "<" ;   # opener of a phrase in B mode
my $Bcloser = ">" ;   # closer of a phrase in B mode
my $Copener = "{" ;   # opener of a phrase in C mode
my $Ccloser = "}" ;   # closer of a phrase in C mode
my $Dopener = "(" ;   # opener of a phrase in D mode
my $Dcloser = ")" ;   # closer of a phrase in D mode
#
my $itembreak = "=========================\n" ;

### main
my $count = 0 ;
my $mode = "" ;
#our @pool ;
#
while ( my $line = <>) {
	next if $line =~ m/^[#%].*/ ;
	chomp $line ;
	next if length($line) == 0;
	$count++ ;
	#
	if ($args{debug}) {
		printf "## raw input $count: $line\n" ;
		printf "## length: %s\n", length($line) ;
		}
	# remove inline comments
	$line =~ s/([^#]+)#.*/$1/ ;
	# removes whitespaces inside
	$line =~ s/ +//g ;
	printf "## input $count: $line\n" ;
	## count parentheses
	my (@A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2) ; # holds the indices for grouping
	for my $i (0..length($line)) {
		if ($args{debug}) { printf "## i: $i\n" ; }
		my $char = substr($line, $i, 1) ;
		if ($args{debug}) { printf "## char: $char\n" ; }
		## build index lists
		## A
		if ($char eq $Aopener) {
			if ($args{debug}) { printf "# $Aopener match at: $i\n" ; }
			push(@A1, $i) ;
		} elsif ($char eq $Acloser) {
			if ($args{debug}) { printf "# $Acloser match at: $i\n" ; }
			push(@A2, $i) ;
		## B
		} elsif ($char eq $Bopener) {
			if ($args{debug}) { printf "# $Bopener match at: $i\n" ; }
			push(@B1, $i) ;
		} elsif ($char eq $Bcloser) {
			if ($args{debug}) { printf "# $Bcloser match at: $i\n" ; }
			push(@B2, $i) ;
		## C
		} elsif ($char eq $Copener) {
			if ($args{debug}) { printf "# $Copener match at: $i\n" ; }
			push(@C1, $i) ;
		} elsif ($char eq $Ccloser) {
			if ($args{debug}) { printf "# $Ccloser match at: $i\n" ; }
			push(@C2, $i) ;
		## D
		} elsif ($char eq $Dopener) {
			if ($args{debug}) { printf "# $Dopener match at: $i\n" ; }
			push(@D1, $i) ;
		} elsif ($char eq $Dcloser) {
			if ($args{debug}) { printf "# $Dcloser match at: $i\n" ; }
			push(@D2, $i) ;
		}
	}
	#
	if ($args{debug}) {
		printf "# A1 indices: %s\n", join(",", @A1) ;
		printf "# A2 indices: %s\n", join(",", @A2) ;
		printf "# B1 indices: %s\n", join(",", @B1) ;
		printf "# B2 indices: %s\n", join(",", @B2) ;
		printf "# C1 indices: %s\n", join(",", @C1) ;
		printf "# C2 indices: %s\n", join(",", @C2) ;
		printf "# D1 indices: %s\n", join(",", @D1) ;
		printf "# D2 indices: %s\n", join(",", @D2) ;
	}
	## generate parses
	#our @pool = [ ] ; # this caused a big mess
	our @pool = ( ) ;
	## process A grouping
	if (scalar(@A1) > 0 && (scalar(@A1) == scalar(@A2))) {
		if ($args{onlyB} || $args{onlyC} || $args{onlyD}) {
			# do nothing
		} else {
			printf "# A components found with matching %d pairs of $Aopener and $Acloser\n", scalar(@A1) ;
			&parse($line, $Aopener, $Acloser) ;
		}
	} else {
		printf "# A components not found: $Aopener and $Acloser missing or mismatching\n"
	}
	## process B grouping
	if (scalar(@B1) > 0 && (scalar(@B1) == scalar(@B2))) {
		if ($args{onlyA} || $args{onlyC} || $args{onlyD}) {
			# do nothing
		} else {
			printf "# B components found with matching %d pairs of $Bopener and $Bcloser\n", scalar(@B1) ;
			&parse($line, $Bopener, $Bcloser) ;
		}
	} else {
		printf "# B components not found: $Bopener and $Bcloser missing or mismatching\n"
	}
	## process C grouping
	if (scalar(@C1) > 0 && (scalar(@C1) == scalar(@C2))) {
		if ($args{onlyA} || $args{onlyB} || $args{onlyD}) {
			# do nothing
		} else {
			printf "# C components found with matching %d pairs of $Copener and $Ccloser\n", scalar(@C1) ;
			&parse($line, $Copener, $Ccloser) ;
		}
	} else {
		printf "# C components not found: $Copener and $Ccloser missing or mismatching\n"
	}
	## process D grouping
	if (scalar(@D1) > 0 && (scalar(@D1) == scalar(@D2))) {
		if ($args{onlyA} || $args{onlyB} || $args{onlyC}) {
			# do nothing
		} else {
			printf "# D components with matching %d pairs of $Dopener and $Dcloser\n", scalar(@D1) ;
			&parse($line, $Dopener, $Dcloser) ;
		}
	} else {
		printf "# D components not found: $Dopener and $Dcloser missing or mismatching\n"
	}
	## prints out pool
	print "# summary:\n" ;
	#map { printf "* component $_ *\n" } (sort @pool) ;
	$i = 0 ;
	for my $component (sort @pool) {
		$i++ ;
		printf "item $count component %2d: $component\n", $i ;
	}
	##
	printf $itembreak ;
}

## functions

sub parse {
	## preparation
	my $string = shift() ;
	if ($args{debug}) { printf "## string: $string\n" ; }
	my $opener = shift() ;
	if ($args{debug}) { printf "## opener: $opener\n" ; }
	my $closer = shift() ;
	if ($args{debug}) { printf "## closer: $closer\n" ; }
	## select mode
	if ($opener eq $Aopener && $closer eq $Acloser ) {
		$mode = "a" ;
	} elsif ($opener eq $Bopener && $closer eq $Bcloser ) {
		$mode = "b" ;
	} elsif ($opener eq $Copener && $closer eq $Ccloser ) {
		$mode = "c" ;
	} elsif ($opener eq $Dopener && $closer eq $Dcloser ) {
		$mode = "d" ;
	}
	## main
	my @subpool = ( ) ;
	my @S = [ ] ;
	my ($j, $position, $count) = (0, 0, 0) ;
	for my $char (split "", $string) { # Crucially
		$j++ ;
		if ($char eq $closer) {
			$count++ ;
			my $start = pop(@S) ;
			my $len = ($position - $start) ;
			my $component = substr($string, $start, $len) ;
			if ($args{debug}) {
				printf "# raw component $mode$count: $component\n" ;
			}
			##
			if ($args{greedy}) {
				my $subcount = 0 ;
				my $component_raw = $component ;
				$component =~ s/[\[\]<>{}()]//g ;
				if ($args{debug} || $args{verbose}) {
					printf "# component $mode$count.$subcount: $component\n" ;
				}
				## update @pool
				push(@main::pool, $component) unless ( any { $_ eq $component } @main::pool );
				push(@subpool, $component) unless ( any { $_ eq $component } @subpool );
				## parse subcomponents
				for my $subcomp (split(/[\[\]<>{}()]+/, $component_raw)) {
					if (length($subcomp) > 0) {
						#if ( any(@pool) eq $subcomp ) { # fails to work
						if ( any {$_ eq $subcomp } @main::pool) {
							# do nothing
						} else {
							$subcount++ ;
							if ($args{debug} || $args{verbose}) {
								printf "# subcomponent $mode$count.$subcount: $subcomp\n" ;
							}
							## update @pool
							push(@main::pool, $subcomp) unless ( any { $_ eq $subcomp } @main::pool ) ;
							push(@subpool, $subcomp) ;
						}
					}
				}
			#
			} else {
				#$component = &clean($component) ;
				$component =~ s/[\[\]<>{}()]//g ; # removes openers and closers
				if ($args{debug} || $args{verbose}) {
					printf "# component $mode$count: $component\n" ;
				}
				## update @pool
				push(@main::pool, $component) unless ( any { $_ eq $component } @main::pool );
				push(@subpool, $component) unless ( any { $_ eq $component } @subpool );
			}
		} elsif ($char eq $opener) {
			push(@S, int($position)) ;
		} else {
			if ($args{debug}) { printf "# char: $char\n" ; }
		}
		$position++ ;
	}
	## dump transitional pool
	if ($args{debug}) {
		printf "# dump(sort \@subpool):\n" ;
		&encoded_dump(sort \@subpool) ;
	}
}

sub encoded_dump {
	my @x= @{shift()} ;
	printf "%s\n", dump(@x) =~ s/((?:\\x\{[\da-f]+\})+)/eval '"'.$1.'"'/eigr ; # worked
}


### end of script
