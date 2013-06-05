#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to read the previous CHMD position file and 
# then copy/append these to the follwoing  XES (GW) templates:
# pw_scf.in             --> gw_*.in1 
# cp_scf.in             --> gw_*.in2 
# pw_nscf.in            --> gw_*.in3 
# cp_nscf.in            --> gw_*.in4
# cp-print_nscf.in      --> gw_*.in4b
# gwlf.in               --> gw_*.in5
# gen-progjections      --> xsf.in
#
# This script will also create outdir for different XES calculations using 
# $var{xes_outdir}.'_'.${ncount}
#
# !!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT: This script is intended to be run from a PBS within the 
# directory created by the xes_init.pl script
# ---> IF NOT this will not work
# !!!!!!!!!!!!!!!!!!!!!!!
#
# OUTPUT: All the GW files as above
#---------------------------------------------------------------------------

use warnings;
use strict;
use File::Copy qw(copy);
use Cwd 'cwd';
use FindBin qw($Bin);

require "$Bin/read_variables.pm";
require "$Bin/create_input.pm";

#Main variables
require "$Bin/mainvar.pl";
our ($input_file, $init_atomic_pos_file, $atomic_pos_file, $xsf_in, $xsf_out, $inout);

#XES (GW) Calculation types
my @xes_cals = ('1', '2', '3', '4', '4b', '5');
#
#---------------------------------------------------------
# Read in input-file.in namelist (Created by gs)
#---------------------------------------------------------
if (! -e "./$input_file"){
   die " ERROR Input File Not Specified : $!";
}
my %var = &read_variables(0, "./$input_file");
#---------------------------------------------------------

#---------------------------------------------------------
# Check the previous Position File of the CHMD
#---------------------------------------------------------
my $chmd_pos_file = cwd().'/'.$var{chmd_outdir}.'/'.$var{prefix}.'.pos'; 
if (! -e $chmd_pos_file){
   die " ERROR CHMD Output Not Found: $!";
}
#---------------------------------------------------------

#---------------------------------------------------------
# Open CHMD position File
#---------------------------------------------------------
#Read in the previous CHMD Calculation
open my $chmd_pos_fh, '<', $chmd_pos_file or die " ERROR: Cannot Open File $chmd_pos_file: $!";
#---------------------------------------------------------



#*********************************************************
# Get the correct atomic postions and append to all template files 
#*********************************************************

#Shift the first value of the xes_steps
my $ncount = shift @{$var{xes_steps}};

#---------------------------------------------------------
#First setup should be BEFORE the CHMD (i.e init_atomic_pos)
#---------------------------------------------------------
if ($ncount == 0){

   #Name and create the current GW outdir
   &create_xes_dir("$var{xes_outdir}_$ncount");
   system(" echo \" CHMD steps = 0, CHMD time = 0.0ps\" > $var{xes_outdir}_$ncount/README");

   #Copy all the XES (GW) templates into gw_*.in1, ... , gw_*.in5 in the $var{xes_outdir}_${ncount}
   #(See above for description of each)
   &copy_xes_templates($ncount, \%var);

   #Check to see if the initial position file exist
   if ( ! -e  $init_atomic_pos_file ){
      die " ERROR: $init_atomic_pos_file Not Found in ".cwd().": $!";
   }
   else {
      #copy this file
      system ("cp $init_atomic_pos_file $var{xes_outdir}_${ncount}/${atomic_pos_file}");
   }

   #Create the five main files
   foreach my $file (@xes_cals){
      my $temp_file = "$var{xes_outdir}_$ncount/${inout}_$ncount.in$file";  
      system("cat $init_atomic_pos_file >> $temp_file");
   }

   #Create the xsf.in file
   system("cp $var{gen_proj_template} $var{xes_outdir}_${ncount}/$xsf_in ");

   #Shift the next value of the xes_steps
   $ncount = shift @{$var{xes_steps}};

}

#---------------------------------------------------------

#---------------------------------------------------------
#Now for the rest of the positions inside the CHMD Output file
#Loop through the position file and find the lines that can only 
#be split into 2 values (Step and time)
#---------------------------------------------------------
while (my $line = <$chmd_pos_fh>){

   if ( (split ' ', $line) == 2){

      #read the *pos fle and get the step and the time
      my ($cur_step, $cur_time) = (split ' ', $line)[0,1];
      next unless ( $ncount == $cur_step);

      &create_xes_dir($var{xes_outdir}.'_'.$ncount);
      system(" echo \" CHMD steps = $cur_step, CHMD time = ${cur_time}ps\" > $var{xes_outdir}_$ncount/README");

      #Copy all the XES (GW) templates into gw_*.in1, ... , gw_*.in4 in the $var{xes_outdir}_${ncount}
      &copy_xes_templates($ncount, \%var);

      #Open atomic postion file
      open my $fh, '>', $var{xes_outdir}.'_'.$ncount.'/'.$atomic_pos_file
         or die " ERROR: Cannto Open $atomic_pos_file: $! ";

      #Read beyond the opening step and time 
      $line = <$chmd_pos_fh>;   

      #print the Excited Oxygen postion to file
      print {$fh} " OO $line";

      #Read beyond the Excited Oxygen
      $line = <$chmd_pos_fh>;   

      #Print the Oxygen (remember on is already print  = OO)
      foreach my $atom (1 .. ($var{numO}-1)){
         
         #print the atomic postion to file
         print {$fh} " O  $line";
         $line = <$chmd_pos_fh>;   
         }

      #Print the Hydrogen
      foreach my $atom (1 .. $var{numH}){
         
         #print the atomic postion to file
         print {$fh} " H  $line";

         #Unless weware at the very last line
         #Read the next line
         unless ( $atom == $var{numH}){
            $line = <$chmd_pos_fh>;   
         }
      }

      close($fh);

      #Create the main files
      foreach my $file (@xes_cals){
         #Append the template files
         my $temp_file = "$var{xes_outdir}_$ncount/${inout}_$ncount.in$file";
         system (" cat $var{xes_outdir}_$ncount/$atomic_pos_file >> $temp_file ");
      }

      #Create the xsf.in file
      #TODO adjust this for the number of states
      system("cp $var{gen_proj_template} $var{xes_outdir}_${ncount}/$xsf_in ");

      #Shift the next value of the xes_steps
      $ncount = shift @{$var{xes_steps}};

   }
}

close($chmd_pos_fh);
#---------------------------------------------------------

#*********************************************************

#######################################################################################
#  Subroutines
#######################################################################################

sub copy_xes_templates{

   #W Gcalculation num
   my $num = shift @_;

   #Hash reference 
   my $var_ref =shift @_;
   my %var = %$var_ref; 

   #Create the PWscf Calculation (val_bands):
   &create_input($var{pw_template}, "$var{xes_outdir}_$num/${inout}_$num.in1", 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{val_bands});

   #Create the CPscf Calculation (val_bands):
   &create_input($var{cp_template}, "$var{xes_outdir}_$num/${inout}_$num.in2", 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{val_bands});

   #Create the PWnscf Calculation (tot_bands):
   &create_input($var{pwnscf_template}, "$var{xes_outdir}_$num/${inout}_$num.in3", 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands});

   #Create the CPnscf Calculation (tot_bands):
   &create_input($var{cpnscf_template}, "$var{xes_outdir}_$num/${inout}_$num.in4", 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands});

   #Create the CPnscf Print out Calculation (tot_bands):
   &create_input($var{cpnscf_print_template}, "$var{xes_outdir}_$num/${inout}_$num.in4b", 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands});

   #Create the GW-lf Calculation (tot_bands AND val_bands):
   &create_input($var{gw_template}, "$var{xes_outdir}_$num/${inout}_$num.in5", 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands},
      'vnbsp'          => $var{val_bands});

} 

sub create_xes_dir{

   #current directory
   my $xes_outdir = shift @_;

   #---------------------------------------------------------
   #XES Outdir: Check, clean or create,
   #---------------------------------------------------------
   if ( -d $xes_outdir ){ 
      #TODO Check if the last calculation contains JOB DONE. IF so remove this from the 
      #the $var{xes_steps}
      print " $xes_outdir exists \n";      
   }
   else {
      mkdir $xes_outdir, 0755 or die " ERROR: Cannot Create Directory $xes_outdir:$!";
   }
   #---------------------------------------------------------
}
