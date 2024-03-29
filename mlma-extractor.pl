#!/usr/bin/env perl -w
#
# developed by Kow Kuroda
# contact: kow.kuroda@gmail.com
# created on 2022/12/11
# modifications:
# 2022/12/12; code refactored by elaborating generates(...) to work.
# 2022/12/13;
# 1) modified generate(...) to handle recursion properly;
# 2) extended to process grouping using { and }, and ( and ).
# 3) added handling of comment lines starting with # or %
# 4) added options for mode selection among A, B, C and D
# 2022/12/20; fixed a bug on @pool handling
# 2023/01/12; added handling of inline comment
# 2023/01/16; change greedy to default behavior, adding switch by gentle;
# 2023/01/18; implemented discontinuity marked by ~ in which A~B~C yields AC as well
# 2023/02/07; fixed a bug in @A1, @A2, ... that resulted in overcounting
# 2023/03/13; made slight modifications
# 2023/03/14; fixed a bug in null line detection
# 2023/05/23; fixed a bug at handling ~ to produce unbalanced match at A
# 2023/05/25; revised code partly
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
   "help|h",         #print help
   "debug",          #debug options
   "verbose|v",      #verbose option
   "gentle|g",       #runs in gentle mode
   "regularize|r",   #regularize input by ignoring dicontinuity marking
   "onlyA|A",        #select A grouping only
   "onlyB|B",        #select B grouping only
   "onlyC|C",        #select C grouping only
   "onlyD|D"         #select D grouping only
);
print_help() if $args{help} ;

## handle implications
if ($args{verbose}) { $args{debug} = 1 ; }

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
my $linker  = "~" ;   # linker of a dicontinuous
#
my $itembreak = "=========================\n" ;

### main
my $count = 0 ;
my $mode  = "" ;
my $padding = 2 ;
##
while ( my $input = <> ) {
   chomp $input ;
   next if $input =~ m/^[#%].*/ or length $input == 0 ;
   $count++ ;
   if ( $args{debug} ) {
      printf "## raw input $count: $input\n" ;
      printf "## length: %s\n", length $input ;
   }
   # remove inline comments
   $input =~ s/([^#]+)#.*/$1/ ;
   # removes whitespaces inside
   $input =~ s/ +//g ;
   # regularize input by removing dicontinuity marking
   if ( $args{regularize} ) {
      $input =~ s/\Q$linker\E//g ;
   }
   printf "## input $count: $input\n" ;
   ##
   our @pool = ( ) ;
   ## holds the indices for grouping
   our (@A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2) ;
   ## process linkers
   my $nchar =  length $input ;
   my $nlinks = $nchar - length( $input =~ s/\Q$linker\E//rg );
   print "# nlinks: $nlinks\n" if $args{debug} ;
   if ( $nlinks > 1 ) {
      my @expanded = &expand_input ($input) ;
      if ( $args{debug} ) {
         for my $added (@expanded) { print "# added: $added\n" ; }
      }
      #
      $input =~ s/$linker//g ; # s///r turns out offensive
      print "# clean_input: $input\n" if $args{debug} ;
      push(@expanded, $input) ;
      # process
      $i = 0 ;
      for my $input ( @expanded ) {
         $i++ ;
         print "# expanded input $i: $input\n" if $args{debug} ;
         print "## cycle $i to handle discontinuity\n" ;
         &process ($input) ;
      }
   } else {
      &process ($input) ;
   }
   ## prints out @pool
   print "## summary:\n" ;
   $i = 0 ;
   for my $component (sort @pool) {
      $i++ ;
      printf "item %2d has component %2d: $component\n", $count, $i ;
   }
   ##
   printf $itembreak ;
   ## re-initialize the arrays
   (@A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2) = ((), (), (), (), (), (), (), ()) ;
}

#
sub expand_input {
   my $line = shift() ;
   #
   my @sublines = split ($linker , $line) ;
   if ( $args{debug} ) {
      print "# sublines: ", join "/ ", @sublines, "\n" ;
      #for my $subline (@sublines) { print "# subline: $subline\n" ; }
   }
   ##
   my $subline_count = scalar @sublines ;
   my @expanded = () ;
   for my $p ( 0..$subline_count ) {
      my $unit1 = $sublines[$p] ;
      my $unit2 = $sublines[$p + 2] ;
      if ( defined $unit2 ) {
         if ( $args{debug} ) { printf "# unit1: $unit1\n# unit2: $unit2\n" ; }
         ### equate parentheses
         ## index openers and closers in unit 1
         my ( @xA1, @xA2, @xB1, @xB2, @xC1, @xC2, @xD1, @xD2 ) ;
         $i = 0;
         for my $c ( split ("", $unit1) ) {
               if ( $c eq $Aopener ) { push (@xA1, $i) ; }
            elsif ( $c eq $Acloser ) { push (@xA2, $i) ; }
            elsif ( $c eq $Bopener ) { push (@xB1, $i) ; }
            elsif ( $c eq $Bcloser ) { push (@xB2, $i) ; }
            elsif ( $c eq $Copener ) { push (@xC1, $i) ; }
            elsif ( $c eq $Ccloser ) { push (@xC2, $i) ; }
            elsif ( $c eq $Dopener ) { push (@xD1, $i) ; }
            elsif ( $c eq $Dcloser ) { push (@xD2, $i) ; }
            $i++ ;
         }
         ## index openers and closers in unit 2
         my (@yA1, @yA2, @yB1, @yB2, @yC1, @yC2, @yD1, @yD2) ;
         $i = 0;
         for my $c ( split ("", $unit2) ) {
              if ( $c eq $Aopener ) { push (@yA1, $i) ; }
            elsif ( $c eq $Acloser ) { push (@yA2, $i) ; }
            elsif ( $c eq $Bopener ) { push (@yB1, $i) ; }
            elsif ( $c eq $Bcloser ) { push (@yB2, $i) ; }
            elsif ( $c eq $Copener ) { push (@yC1, $i) ; }
            elsif ( $c eq $Ccloser ) { push (@yC2, $i) ; }
            elsif ( $c eq $Dopener ) { push (@yD1, $i) ; }
            elsif ( $c eq $Dcloser ) { push (@yD2, $i) ; }
            $i++ ;
         }
         ## get A-discrepancy
         my $disA = ( @xA1 + @yA1 ) - ( @xA2 + @yA2 ) ;
         if ( $args{debug} ) { printf "# disA: %d\n", $disA ; }
         if ( $disA >= 0 ) {
            for $i ( 0 .. ($disA - 1) ) { $unit2 =~ s/\Q$Aopener// ; }
         } elsif ( $disA < 0 ) {
            for $i (0 .. (-$disA - 1) ) { $unit2 =~ s/\Q$Acloser// ; }
         }
         ## get B-discrepancy
         my $disB = ( @xB1 + @yB1 ) - ( @xB2 + @yB2 ) ;
         if ( $args{debug} ) { printf "# disB: %d\n", $disB ; }
         if ( $disB >= 0 ) {
            for $i ( 0 .. ($disB - 1) ) { $unit2 =~ s/\Q$Bopener// ; }
         } elsif ( $disB < 0 ) {
            for $i ( 0 .. (-$disB - 1) ) { $unit2 =~ s/\Q$Bcloser// ; }
         }
         ## get C-discrepancy
         my $disC = ( @xC1 + @yC1 ) - ( @xC2 + @yC2 ) ;
         if ( $args{debug} ) { printf "# disC: %d\n", $disC ; }
         if ( $disC >= 0 ) {
            for $i ( 0 .. ($disC - 1) ) { $unit2 =~ s/\Q$Copener// ; }
         } elsif ( $disC < 0 ) {
            for $i ( 0 .. (-$disC - 1) ) { $unit2 =~ s/\Q$Ccloser// ; }
         }
         ## get D-discrepancy
         my $disD = ( @xD1 + @yD1 ) - ( @xD2 + @yD2 ) ;
         if ( $args{debug} ) { printf "# disD: %d\n", $disD ; }
         if ( $disD >= 0 ) {
            for $i ( 0 .. ($disD - 1) ) { $unit2 =~ s/\Q$Dopener// ; }
         } elsif ( $disD < 0 ) {
            for $i ( 0 .. (-$disD - 1) ) { $unit2 =~ s/\Q$Dcloser// ; }
         }
         ## add handling of mismatched parentheses here
         my $combined = $unit1 . $unit2 ;
         if ( length $combined > length $unit1 ) {
            push (@expanded, $combined) unless ( any { $_ eq $combined } @expanded ) ;
         }
      }
   }
   return @expanded ;
}

#
sub process {
   my $line = shift() ;
   ## count parentheses
   &count_parentheses ($line) ;
   #our (@A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2) = ((), (), (), (), (), (), (), ()); # holds the indices for grouping
   
   ## the following fails
   #(@A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2) = &count_parentheses ($line, @A1, @A2, @B1, @B2, @C1, @C2, @D1, @D2) ;
   ## check result
   if ( $args{debug} ) {
      printf "# A1 indices: %s\n", join(",", @main::A1) ;
      printf "# A2 indices: %s\n", join(",", @main::A2) ;
      printf "# B1 indices: %s\n", join(",", @main::B1) ;
      printf "# B2 indices: %s\n", join(",", @main::B2) ;
      printf "# C1 indices: %s\n", join(",", @main::C1) ;
      printf "# C2 indices: %s\n", join(",", @main::C2) ;
      printf "# D1 indices: %s\n", join(",", @main::D1) ;
      printf "# D2 indices: %s\n", join(",", @main::D2) ;
   }
   ## generate parses
   ##our @pool = [ ] ; # this caused a big mess
   #our @pool = ( ) ;
   ## process A grouping
   if ( scalar @main::A1 > 0 && (scalar @main::A1 == scalar @main::A2) ) {
      if ( $args{onlyB} and $args{onlyC} and $args{onlyD} ) {
         # do nothing
      } else {
         printf "# A components found with matching %d pair(s) of $Aopener and $Acloser\n",
            scalar @main::A1 ;
         &parse($line, $Aopener, $Acloser) ;
      }
   } else {
      printf "# A components not found: $Aopener and $Acloser missing or mismatching\n" }
   ## process B grouping
   if ( scalar @main::B1 > 0 && (scalar @main::B1 == scalar @main::B2) ) {
      if ( $args{onlyA} and $args{onlyC} and $args{onlyD} ) {
         # do nothing
      } else {
         printf "# B components found with matching %d pair(s) of $Bopener and $Bcloser\n",
            scalar(@main::B1) ;
         &parse ($line, $Bopener, $Bcloser) ;
      }
   } else {
      printf "# B components not found: $Bopener and $Bcloser missing or mismatching\n" }
   ## process C grouping
   if ( scalar @main::C1 > 0 && ( scalar @main::C1 == scalar @main::C2 ) ) {
      if ( $args{onlyA} and $args{onlyB} and $args{onlyD} ) {
         # do nothing
      } else {
         printf "# C components found with matching %d pair(s) of $Copener and $Ccloser\n",
            scalar @main::C1 ;
         &parse ($line, $Copener, $Ccloser) ;
      }
   } else {
      printf "# C components not found: $Copener and $Ccloser missing or mismatching\n" }
   ## process D grouping
   if ( scalar @main::D1 > 0 && (scalar @main::D1 == scalar @main::D2) ) {
      if ( $args{onlyA} and $args{onlyB} and $args{onlyC} ) {
         # do nothing
      } else {
         printf "# D components with matching %d pair(s) of $Dopener and $Dcloser\n",
            scalar @main::D1 ;
         &parse ($line, $Dopener, $Dcloser) ;
      }
   } else {
      printf "# D components not found: $Dopener and $Dcloser missing or mismatching\n" }
}

#
sub count_parentheses {
   #
   my $linex = shift() ;
   #
   for my $i ( 0..length $linex ) {
      if ( $args{debug} ) { printf "## i: $i\n" ; }
      my $char = substr($linex, $i, 1) ;
      if ( $args{debug} ) { printf "## char: $char\n" ; }
      ## build index lists
      ## A
      if ( $char eq $Aopener ) {
         if ( $args{debug} ) { printf "# $Aopener match at: $i\n" ; }
         push(@main::A1, $i) ;
      } elsif ( $char eq $Acloser ) {
         if ( $args{debug} ) { printf "# $Acloser match at: $i\n" ; }
         push (@main::A2, $i) ;
      ## B
      } elsif ( $char eq $Bopener ) {
         if ( $args{debug} ) { printf "# $Bopener match at: $i\n" ; }
         push(@main::B1, $i) ;
      } elsif ( $char eq $Bcloser ) {
         if ( $args{debug} ) { printf "# $Bcloser match at: $i\n" ; }
         push (@main::B2, $i) ;
      ## C
      } elsif ( $char eq $Copener ) {
         if ($args{debug}) { printf "# $Copener match at: $i\n" ; }
         push(@main::C1, $i) ;
      } elsif ( $char eq $Ccloser ) {
         if ( $args{debug} ) { printf "# $Ccloser match at: $i\n" ; }
         push (@main::C2, $i) ;
      ## D
      } elsif ( $char eq $Dopener ) {
         if ($args{debug}) { printf "# $Dopener match at: $i\n" ; }
         push (@main::D1, $i) ;
      } elsif ( $char eq $Dcloser ) {
         if ( $args{debug} ) { printf "# $Dcloser match at: $i\n" ; }
         push (@main::D2, $i) ;
      }
   }
}

#
sub parse {
   ## preparation
   my $string = shift() ;
   printf "## string: $string\n" if $args{debug} ;
   my $opener = shift() ;
   printf "## opener: $opener\n" if $args{debug} ;
   my $closer = shift() ;
   printf "## closer: $closer\n" if $args{debug} ;
   ## select mode
   if ( $opener eq $Aopener && $closer eq $Acloser ) {
      $mode = "a" ;
   } elsif ( $opener eq $Bopener && $closer eq $Bcloser ) {
      $mode = "b" ;
   } elsif ( $opener eq $Copener && $closer eq $Ccloser ) {
      $mode = "c" ;
   } elsif ( $opener eq $Dopener && $closer eq $Dcloser ) {
      $mode = "d" ;
   }
   ## main
   my @subpool = ( ) ;
   my @S = [ ] ;
   my ($j, $position, $count) = (0, 0, 0) ;
   for my $char (split "", $string) { # Crucially
      $j++ ;
      if ( $char eq $closer ) {
         $count++ ;
         my $start = pop(@S) ;
         my $len = ($position - $start) ;
         my $component = substr($string, $start, $len) ;
         printf "# raw component $mode$count: $component\n" if $args{debug} ;
         ##
         if ( $args{gentle} ) {
            $component =~ s/[\[\]<>{}()]//g ; # removes openers and closers
            printf "# component $mode$count: $component\n" if $args{verbose} ;
            ## update @pool
            push(@main::pool, $component) unless ( any { $_ eq $component } @main::pool ) ;
            push(@subpool, $component) unless ( any { $_ eq $component } @subpool ) ;
         } else {
            my $subcount = 0 ;
            my $component_raw = $component ;
            $component =~ s/[\[\]<>{}()]//g ;
            printf "# component $mode$count.$subcount: $component\n" if $args{verbose} ;
            ## update @pool
            push(@main::pool, $component) unless ( any { $_ eq $component } @main::pool ) ;
            push(@subpool, $component) unless ( any { $_ eq $component } @subpool ) ;
            ## parse subcomponents
            for my $subcomp (split(/[\[\]<>{}()]+/, $component_raw)) {
               if ( length $subcomp > 0 ) {
                  if ( any {$_ eq $subcomp } @main::pool) {
                     # do nothing
                  } else {
                     $subcount++ ;
                     printf "# subcomponent $mode$count.$subcount: $subcomp\n" if $args{verbose} ;
                     ## update @pool
                     push(@main::pool, $subcomp) unless ( any { $_ eq $subcomp } @main::pool ) ;
                     push(@subpool, $subcomp) ;
                  }
               }
            }
         }
      } elsif ( $char eq $opener ) {
         push(@S, int($position)) ;
      } else {
         printf "# char: $char\n" if $args{debug} ;
      }
      $position++ ;
   }
   ## dump transitional pool
   if ( $args{debug} ) {
      printf "# dump(sort \@subpool):\n" ;
      &encoded_dump(sort \@subpool) ;
   }
}

#
sub count_char {
   my $char = shift() ;
   my $original = shift() ;
   my $converted = $original =~ s/$char//g ;
   return length $original - length $converted ;
}

#
sub encoded_dump {
   my @x= @{shift()} ;
   printf "%s\n", dump(@x) =~ s/((?:\\x\{[\da-f]+\})+)/eval '"'.$1.'"'/eigr ; # worked
}


### end of script
