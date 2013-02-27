#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to create the qsub PBS script for individual excited Atoms 
# 
#
# INPUT: 1) Number of the currently excited atom 
#        2) Hash ref for var
#        3) Current Directory for the excited atom
#        4) $exe_home the pathname of the of the scripts directory
#
# OUTPUT: 1)
#----------------------------------------------------------------------------

use warnings;
use strict;
use 5.012;
use File::Copy qw(copy);
use Cwd 'cwd';

sub create_qsub{

   #number of the currently excited atom
   my $num = shift @_;

   #Main variable
   my $var_ref = shift @_;
   my %var = %$var_ref;

   #Absolute Pathname
   my $current_dir = shift @_;
   my $pathname = cwd().'/'.$current_dir;

   #Pathname of the scripts directory
   my $exe_home = shift @_; 

   #open and read in the submit_template
   open my $submit_template_fh, '<', $var{submit_template} 
      or die " ERROR: Cannot Open File $var{submit_template} :$!"; 
   my @template = <$submit_template_fh>;

   #TODO Add Error Checks fo the PBS File

   #open Actual Submit File
   my $submit_script = $current_dir.'/'.'submit.cmd';
   open my $submit_fh, '>', $submit_script
      or die " ERROR: Cannot Open File $submit_script : $!";
   select $submit_fh;

   #Start the copying process
   print  @template;

#------------------------------------------------------
#Create the Here-Document
#------------------------------------------------------
print <<EOF;

#This portion of the command script was generated automatically
#Edit it and you will get what you deserve

cd $pathname

#Run the Groundstate Calculation
aprun -n $var{procs} $var{gs_qe} < gs.in > gs.out

#Set up and run the CHMD Calculations
${exe_home}/create_chmd.pl $num
aprun -n $var{procs} $var{chmd_qe} < gs.in > gs.out

#Set up and run the GW Calculations
${exe_home}/create_gw.pl
for num in 1 2 3 
do
#TODO Adde the total Local Field
aprun -n $var{procs} $var{gs_qe} < gs.in\${num} > gs.out\${num}
done

${exe_home}/create_xes.pl

EOF
#------------------------------------------------------
select STDIN;
close($submit_fh);
}
1;
