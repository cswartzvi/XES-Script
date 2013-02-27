#! /usr/bin/perl
#----------------------------------------------------------------------------
# This Subroutine will take the input file and change some of the run-time
# parameters such as, prefix, pseudo, outdir, nat, and celldm
# 
#
# INPUT: 1) reference to hash %var 
#        2) key that contains the template file in the above hash
#
# OUTPUT: 1) Altered Template File (NOT returned!)
#----------------------------------------------------------------------------

use warnings;
use strict;
use 5.012;
use File::Copy qw(copy);
use Cwd 'cwd';

sub alter_input{

   my $var_ref = shift @_;
   my %var = %$var_ref;
   my $template_key = shift @_;

   #Update these values to the current ones --> MUST be in the hash %var!!!
   my @names = qw# prefix pseudo_dir outdir nat celldm #;

   # Set the value of the outdir depending on the value of $template_key
   my $outdir;
   if ( $template_key eq 'chmd_template'){
      $outdir =  $var{chmd_outdir};
   }
   elsif ( $template_key eq 'gs_template'){
      $outdir =  $var{gs_outdir};
   }
   else {
      die " ERROR: Template key $template_key not vaild : $!";
   }

   #Open the template File and read in to an array
   open my $temp_fh, '<', $var{$template_key} or die " ERROR: Cannot Open $var{$template_key}: $!";
   my @template = <$temp_fh>;
   close ($temp_fh);

   #loop through the template file, find matching names
   foreach my $line (@template) {
      foreach my $name (@names){

         #Find the lines that need to be changed
         if ( $line =~ /$name/ ){

            #Catch the outdir (not a key value)
            if ($name eq 'outdir'){
               $line = "  $name = ./$outdir\n";
            }
            #Cathc the celldm, needs (1) in the title
            elsif ($name eq 'celldm'){
               $line = "  $name(1) = $var{$name}\n";
            }
            else {
               $line = "  $name = $var{$name}\n";
            }

         }
      }
   }

   #Open the current template file and replace
   open  $temp_fh, '>', $var{$template_key} or die " ERROR: Cannot Open $var{$template_key}: $!";
   foreach my $line (@template){
      print {$temp_fh} $line;
   }
   close($temp_fh);

}
1;
