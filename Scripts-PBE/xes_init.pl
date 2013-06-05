#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to convert to take the gs.in template and create multiple 
# Ground-State Files with Different Atoms being excited
#
# INPUT: 1) Inputfile XES.in 
#
#----------------------------------------------------------------------------

use warnings;
use strict;
use File::Copy qw(copy);
use FindBin qw($Bin);

#Main variables
require "$Bin/mainvar.pl";
our ($main_input_file, $input_file, $init_atomic_pos_file, $gs_in, $gs_out);

#Required scripts
require "$Bin/read_variables.pm";
require "$Bin/create_input.pm";
require "$Bin/create_qsub.pm";
require "$Bin/xml_data_parse.pm";
require "$Bin/stau_to_tau.pm";

#---------------------------------------------------------
# Read in STDIN namelist 
#---------------------------------------------------------
$main_input_file = shift @ARGV ;
if (! $main_input_file){
   die " ERROR Input File Not Specified : $!";
}
my %var = &read_variables(1, $main_input_file);
&stdout_variables(\%var);
#---------------------------------------------------------

#---------------------------------------------------------
# Parse the xml Data-File from the MD Simulation for STEP0 and STEPM
#---------------------------------------------------------
&xml_data_parse($var{md_xml}, $var{main_dir}, 'taui', 'force', 'stau', 'svel', 'ht')
   or die " ERROR: Cannot Parse xml Data!";
#---------------------------------------------------------

#---------------------------------------------------------
# Convert stau to tau from the previous MD Simulation
#---------------------------------------------------------
&stau_to_tau( "$var{main_dir}/ht_STEP0.dat", "$var{main_dir}/stau_STEP0.dat", $var{main_dir}) 
   or die " ERROR: Cannot convert stua to tau!";

#Open the tau.dat created by stau_to_tau read into an array
open my $atoms_fh, '<', "$var{main_dir}/tau.dat" or die " ERROR: Cannot Open File $!";
my @atoms = <$atoms_fh>;
close($atoms_fh);
#---------------------------------------------------------


MAIN: foreach my $ncount ( $var{config_start} .. $var{config_stop} ){
   
   #Create the Directories
   my $cur_dir = "Oxygen_$ncount";
   print "\n---------------------------------------------------\n\n";
   print " Oxygen: $ncount\n\n";
   
   #----------------------------------------------
   #Check if the files exist, clean or create
   #----------------------------------------------
   $var{gs_skip} = 0; #needs to be reset for each Oxygen

   if ( -d $cur_dir ){ 

      print " $cur_dir found, checking previous GroundState calculation...\n";
      #Check to see if the $var{gs_outdir} exists
      if ( -d "$cur_dir/$var{gs_outdir}" ){
         print " $cur_dir/$var{gs_outdir} exists\n";

         #check to see if the gs.out file exists
         if ( -f "$cur_dir/$var{gs_outdir}/$gs_out"){
            print " $cur_dir/$var{gs_outdir}/$gs_out exists\n";

            #check to see if the job was completed (system call)
            my $temp = `grep -q \"JOB DONE\" $cur_dir/$var{gs_outdir}/$gs_out; echo \$?`;
            if ( $temp == 0){
               print " Previous GS was completed, skipping the groundstate.\n";
               $var{gs_skip} = 1;
            }
            else{
               print " Previous GS was NOT completed\n";
               unlink glob "$cur_dir/$var{gs_outdir}/*" 
            }

         }
         else{
            print " No Previous $gs_out file found, cleaning directory contents.\n";
            unlink glob "$cur_dir/$var{gs_outdir}/*" 
         }
      }
      else {
         print " No $var{gs_outdir} found in $cur_dir, creating $cur_dir/$var{gs_outdir}\n";
         mkdir "$cur_dir/$var{gs_outdir}", 0755 or die " ERROR: Cannot Create Directory ($!)";
      }
   }
   else {
      print " Creating $cur_dir\n";
      mkdir $cur_dir, 0755 or die " ERROR: Cannot Create Directory ($!)";
      print " Creating $cur_dir/$var{gs_outdir}\n";
      mkdir "$cur_dir/$var{gs_outdir}", 0755 or die " ERROR: Cannot Create Directory ($!)";
   }
   print "\n";
   #----------------------------------------------
   
   unless ($var{gs_skip}){
      #----------------------------------------------
      # Create the init_atomic_pos.dat file that will 
      # have  all atoms with their atomic symbol  
      # (Will depend on the current excited Oxygen)
      # This will me useful later
      #----------------------------------------------
      open my $atomic_pos_fh, '>', "$cur_dir/$init_atomic_pos_file" or die "ERROR: Cannot Open File ($!)";
      select $atomic_pos_fh;

      #Print the OO Atom to be excited in the current Configuration
      print 'OO '.$atoms[$ncount - 1];

      #print the Rest of the Atoms
      my $Ocount = 0;
      foreach my $index (0 .. $#atoms){
         if ( $Ocount < $var{numO}) {
            if ( $index != ($ncount - 1) ) {
               print 'O  '.$atoms[$index];
               $Ocount++;
            }
            else {
               #Still need to move the counter along
               $Ocount++;
            }
         }
         else {
               print 'H  '.$atoms[$index];
         }
      }
      select STDOUT;
      close ($atomic_pos_fh);
      #----------------------------------------------

      #----------------------------------------------
      # Copy/append the GS template with atomic positions
      #----------------------------------------------
      &create_input($var{gs_template}, "$cur_dir/$var{gs_outdir}/$gs_in", 
         'prefix'         => $var{prefix},
         'pseudo_dir'     => $var{pseudo_dir},
         'outdir'         => './',
         'nat'            => $var{nat},
         'celldm(1)'      => $var{celldm},
         'nbnd'           => $var{val_bands});
      
      # Append the Groundstate input File
      system("cat $cur_dir/$init_atomic_pos_file >> $cur_dir/$var{gs_outdir}'/$gs_in'");
      #----------------------------------------------
   }

   #----------------------------------------------
   # Copy the input hash to the directory for 
   # use by other scripts
   #----------------------------------------------
   &write_variables(\%var, $cur_dir);
   #----------------------------------------------

   #----------------------------------------------
   # Create PBS Submit Script 
   #----------------------------------------------
   &create_qsub($ncount, \%var,$cur_dir);
   #----------------------------------------------

} 
