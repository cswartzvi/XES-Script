#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to read the previous CHMD output file and find printed 
# ATOMIC_POSITIONS tags, then copy/append these to the follwoing GW templates:
# pw_scf.in       --> gw_1.in* 
# cp_scp.in       --> gw_2.in*
# pw_nscf.in      --> gw_3.in* 
# cp_nscf.in      --> gw_4.in*
# gw_cohsex.in    --> gw_5.in*
#
# This script will also create outdir for different GW calculations using 
# $var{gw_outdir}.'_'.${ncount}
#
# !!!!!!!!!!!!!!!!!!!!!!!
# IMPORTANT: This script is intended to be run from a PBS within the 
# directory created by the xes_init.pl script
# ---> IF NOT this will not work
# !!!!!!!!!!!!!!!!!!!!!!!
#
# OUTPUT: All the GW input files as above
#---------------------------------------------------------------------------

use warnings;
use strict;
use File::Copy qw(copy);
use Cwd 'cwd';

require '/global/homes/c/cswartz/Scripts/XES_Script/Scripts/read_variables.pm';
require '/global/homes/c/cswartz/Scripts/XES_Script/Scripts/create_input.pm';

#---------------------------------------------------------
# Read in input-file.in namelist (Created by gs)
#---------------------------------------------------------
if (! -e './input-file.in'){
   die " ERROR Input File Not Specified : $!";
}
my %var = &read_variables(0, './input-file.in');
#---------------------------------------------------------

#---------------------------------------------------------
# Check the previous output of the CHMD
#---------------------------------------------------------
my $chmd_out = cwd().'/'.$var{chmd_outdir}.'/chmd.out'; 
if (! -e $chmd_out){
   die " ERROR CHMD Output Not Found: $!";
}
#---------------------------------------------------------

#---------------------------------------------------------
# Open CHMD Output File
#---------------------------------------------------------
#Read in the previous CHMD Calculation
open my $chmd_out_fh, '<', $chmd_out or die " ERROR: Cannot Open File $chmd_out: $!";
#---------------------------------------------------------



#*********************************************************
# Get the correct atomic postions and append to all template files 
#*********************************************************

#File with current GW Atomic Positions
my $atomic_pos_file = 'atomic_pos.dat';

#---------------------------------------------------------
#First setup should be BEFORE the CHMD (i.e init_atomic_pos)
#---------------------------------------------------------
my $ncount = 1;

#Name and create the current GW outdir
&create_dir($var{gw_outdir}.'_'.$ncount);

#Copy all the gw templates into gw_1.in*, ... , gw_5.in* in the $var{gw_outdir}_${ncount}
#(See above for description of each)
&copy_gw_templates($ncount, \%var);

#Atomic postion files (Used later in the scripts)
my $init_atomic_pos_file = './init_atomic_pos.dat';

#Check to see if the initial position file exist
if ( ! -e  $init_atomic_pos_file ){
   die " ERROR: $init_atomic_pos_file Not Found in ".cwd().": $!";
}
else {
   #copy this file
   system ("cp $init_atomic_pos_file $var{gw_outdir}'_'${ncount}'/'${atomic_pos_file}");
}

#Append all the input templates
foreach my $file ( 1 .. 5){
   my $temp_file = $var{gw_outdir}.'_'.${ncount}.'/gw_'.${file}.'.in'.${ncount};  
   system("cat $init_atomic_pos_file >> $temp_file");
}
#---------------------------------------------------------

#---------------------------------------------------------
#Now for the rest of the positions inside the CHMD Output file
#Loop through the output file and find the ATOMIC_POSITIONS
#---------------------------------------------------------
while (my $line = <$chmd_out_fh>){
  
   if ($line =~ /ATOMIC_POSITIONS/){

      #Update counter and copy to the new files and create new directory
      $ncount++;

      #Name and create new directory
      &create_dir($var{gw_outdir}.'_'.$ncount);

      #Copy all the gw templates into gw_1.in*, ... , gw_5.in* in the $var{gw_outdir}_${ncount}
      &copy_gw_templates($ncount, \%var);

      #Open atomic postion file
      open my $fh, '>', $var{gw_outdir}.'_'.$ncount.'/'.$atomic_pos_file
         or die " ERROR: Cannto Open $atomic_pos_file: $! ";

      #Read beyond the ATOMIC_POSITIONS Tag
      $line = <$chmd_out_fh>;   

      foreach my $atom (1 .. $var{nat}){
         
         #print the atomic postion to file
         print {$fh} "$line";

         #Unless weware at the very last line
         #Read the next line
         unless ( $atom == $var{nat}){
            $line = <$chmd_out_fh>;   
         }

      }

      close($fh);

      foreach my $file (1 .. 5){
         #Append the template files
         my $temp_file = $var{gw_outdir}.'_'.$ncount.'/gw_'.$file.'.in'.$ncount;
         system (" cat $var{gw_outdir}_$ncount/$atomic_pos_file >> $temp_file ");
      }
   }
}

close($chmd_out_fh);
#---------------------------------------------------------

#*********************************************************

#######################################################################################
#  Subroutines
#######################################################################################

sub copy_gw_templates{

   #GW calculation num
   my $num = shift @_;

   #Hash reference 
   my $var_ref =shift @_;
   my %var = %$var_ref; 

   #Create the PWscf Calculation (val_bands):
   &create_input($var{gw_pw_template}, $var{gw_outdir}.'_'.$num.'/gw_1.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{val_bands});

   #Create the CPscf Calculation (val_bands):
   &create_input($var{gw_cp_template}, $var{gw_outdir}.'_'.$num.'/gw_2.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{val_bands});

   #Create the PWnscf Calculation (tot_bands):
   &create_input($var{gw_pwnscf_template}, $var{gw_outdir}.'_'.$num.'/gw_3.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands});

   #Create the CPnscf Calculation (tot_bands):
   &create_input($var{gw_cpnscf_template}, $var{gw_outdir}.'_'.$num.'/gw_4.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands});

   #Create the GW-lf Calculation (tot_bands AND val_bands):
   &create_input($var{gw_template}, $var{gw_outdir}.'_'.$num.'/gw_5.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => './',
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands},
      'vnbsp'          => $var{val_bands});

} 

sub create_dir{

   #current directory
   my $gw_outdir = shift @_;

   #---------------------------------------------------------
   #GW Outdir: Check, clean or create,
   #---------------------------------------------------------
   if ( -d $gw_outdir ){ 
      unlink glob "$gw_outdir/*" or warn " WARNING: Cannot delete contents of Directory $gw_outdir:$!";
   }
   else {
      mkdir $gw_outdir, 0755 or die " ERROR: Cannot Create Directory $gw_outdir:$!";
   }
   #---------------------------------------------------------
}
