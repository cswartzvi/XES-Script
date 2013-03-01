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
# IMPORTANT: This script is intended to be run from a PBS within the 
# directory created by the create_gs.pl script
# ---> IF NOT this will not work
#
# INPUT 1) Number of current excited atom
#---------------------------------------------------------------------------

use warnings;
use strict;
use File::Copy qw(copy);
use Cwd 'cwd';

require '/home/charles/Desktop/Research/XES_Project/XES_Program/Scripts/read_variables.pm';
require '/home/charles/Desktop/Research/XES_Project/XES_Program/Scripts/create_input.pm';

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
my $chmd_out = cwd().'/chmd.out'; 
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

#---------------------------------------------------------
# Get the correct atomic postions and append to all template files 
#---------------------------------------------------------
my $ncount = 1;

#Copy all the gw templates into gw_1.in*, gw_2.in*, ... , gw_5.in*
#(See above for description of each)
&copy_gw_templates($ncount, \%var);

#Create the outdir
&create_dir($var{gw_output}.'_'.$ncount);

#First setup should be BEFORE the CHMD (i.e init_atomic_pos)
my $atomic_pos_file = './init_atomic_pos.dat';
if ( ! -e  $atomic_pos_file ){
   die " ERROR: $atomic_pos_file Not Found in ".cwd().": $!";
}
foreach my $file ( 1 .. 5){
   system("cat $atomic_pos_file >> gw_${file}.in${ncount}");
}

#Now for the rest of the positions inside the CHMD Output file
#Loop through the output file and find the ATOMIC_POSITIONS
while (my $line = <$chmd_out_fh>){
  
   if ($line =~ /ATOMIC_POSITIONS/){

      #Update counter and copy to the new files and create new directroy
      $ncount++;
      &copy_gw_templates($ncount, \%var);
      &create_dir($var{gw_output}.'_'.$ncount);

      my @temp;
      $line = <$chmd_out_fh>;   

      foreach my $atom (1 .. $var{nat}){
         
         #Store the atomic position
         #shift to the true array index
         $temp[$atom-1] = $line;

         #Unless weware at the very last line
         #Read the next line
         unless ( $atom == $var{nat}){
            $line = <$chmd_out_fh>;   
         }

      }

      foreach my $file (1 .. 5){
         open my $fh, '>>', 'gw_'.$file.'.in'.$ncount 
            or die " ERROR: Cannot Open File ".'gw_'.$file.'.in'.$ncount.": $!";
         print {$fh} @temp;
         close($fh);
      }
   }
}

close($chmd_out_fh);
#---------------------------------------------------------

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
   &create_input($var{gw_pw_template}, 'gw_1.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => $var{gw_outdir},
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{val_bands});

   #Create the CPscf Calculation (val_bands):
   &create_input($var{gw_cp_template}, 'gw_2.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => $var{gw_outdir},
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{val_bands});

   #Create the PWnscf Calculation (tot_bands):
   &create_input($var{gw_pwnscf_template}, 'gw_3.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => $var{gw_outdir},
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands});

   #Create the CPnscf Calculation (tot_bands):
   &create_input($var{gw_cpnscf_template}, 'gw_4.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => $var{gw_outdir},
      'nat'            => $var{nat},
      'celldm(1)'      => $var{celldm},
      'nbnd'           => $var{tot_bands});

   #Create the GW-lf Calculation (tot_bands AND val_bands):
   &create_input($var{gw_template}, 'gw_5.in'.$num, 
      'prefix'         => $var{prefix},
      'pseudo_dir'     => $var{pseudo_dir},
      'outdir'         => $var{gw_outdir},
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
