#! /usr/bin/perl
#----------------------------------------------------------------------------
# This Subroutine will take the input file and change some of the run-time
# parameters such as, prefix, pseudo, outdir, nat, and celldm
# 
#
# INPUT: 1) Template File
#        2) New File (template will be copied to this location)  
#        3) Hash of change values (Ex: prefix pseudo_dir outdir nat celldm ...) 
#
# OUTPUT: 1) Altered Template File (NOT returned!)
#----------------------------------------------------------------------------

use warnings;
use strict;
use 5.012;
use File::Copy qw(copy);
use Cwd 'cwd';

sub create_input{

   #Check the invocation list
   if (@_ < 2){
      die " ERROR: create_input called with no input "
   }

   #Invocation variables
   my $temp_file = shift @_;
   my $file = shift @_;
   my %replace =  @_;

   #------------------------------------------------------
   # Open Files
   #------------------------------------------------------
   #Open the template File and read in to an array
   open my $temp_fh, '<', $temp_file or die " ERROR: Cannot Open $temp_file: $!";
   my @template = <$temp_fh>;
   close ($temp_fh);

   #Open the Destination file (input file)
   open my $des_fh, '>', $file or die " ERROR: Cannot Open $file: $!";
   select $des_fh;
   #------------------------------------------------------

   #------------------------------------------------------
   #Loop through the template file, find matching names
   #------------------------------------------------------
   FILE_LOOP: foreach my $line (@template) {
      while (my ($key, $value) = each %replace){

         my $temp_key = quotemeta $key;
         #Find the lines that need to be changed
         if ( $line =~ /$temp_key/ ){
            printf "  %-13s = %-10s \n", $key, $value;      

            #Reset the keys iterator
            keys %replace;
            #Move the FILE_LOOP forear one if this is found
            next FILE_LOOP; 
         }
      }
      #if none of the tags matched
      print $line;
   }
   
   select STDOUT;
   close ($des_fh);

}
1;
