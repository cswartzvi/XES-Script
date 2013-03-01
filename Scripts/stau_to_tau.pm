#! /usr/bin/perl
#----------------------------------------------------------------------------
# Subroutine to convert the scaled positions into Real Positions to be used in
# input file for the Ground-state calculations
#
# INPUT: 1) Cell (ht) tag Pathname
#        2) stau tag Pathname
#        3) output directory
#
# OUTPUT: 1) atoms File
#----------------------------------------------------------------------------

use warnings;
use strict;

sub stau_to_tau{
   #unit cell matirx, scaled and real coordinates
   my (@ht, @stau, @tau);

   #File containing the Unit cell
   my $cell_file = shift @_;
   open my $cell_fh, '<', $cell_file or die " ERROR: Cannot open File ($!) ";

   #File containing stau 
   my $stau_file = shift @_;
   open my $stau_fh, '<', $stau_file or die " ERROR: Cannot open File ($!) ";

   #Output Directory
   my $dir = shift @_;
   $dir =~ s/\/\z//;
   open my $output_fh, '>', $dir.'/atoms.dat' or die " ERROR: Cannot open File ($!) ";

   #---------------------------------------------
   # Read in the ht (cell) File
   #---------------------------------------------
    
   #Test first line of the Cell File
   if (<$cell_fh> !~ /<ht.*/){
      die " ERROR: $cell_file is NOT an atomic positions File!\n"; 
   }

   #Read in the cell matrix
   foreach my $i (0 .. 2){
      foreach my $j (0 .. 2){
         chomp($ht[$i][$j] = <$cell_fh>);
      }
   }
   #---------------------------------------------

   #---------------------------------------------
   # Read in the stau File
   #---------------------------------------------

   #Test first line of the stau file, and read the next line
   if (<$stau_fh> !~ /<stau.*/){
      die " ERROR: $stau_file is NOT an atomic positions File!\n"; 
   }
   chomp(my $line = <$stau_fh>);

   my $ncount=0;
   while ( $line !~ /<\/stau>/){
      #Add a Line to remove the issue with negative signs in the first column
      $line = ' '.$line;

      #Now, with the space, split the temp
      my @temp = split /\s+/, $line;
      ($stau[$ncount][0], $stau[$ncount][1], $stau[$ncount][2]) = splice @temp, 1;

      #Read next line iterate the counter
      chomp($line = <$stau_fh>);
      $ncount++;
   }
   #---------------------------------------------
      
   #---------------------------------------------
   # Find the Real Atomic Coordinates and print
   #---------------------------------------------
   select $output_fh;    
   foreach my $i ( 0 .. ($ncount-1) ){
      foreach my $j (0 .. 2){
         foreach my $k (0 .. 2){
            $tau[$i][$j] += $ht[$j][$k] * $stau[$i][$k];
         }
         printf "  %25.15E", $tau[$i][$j];
      }
      printf " \n";
   }
   #---------------------------------------------

   select STDIN;
}
1;
