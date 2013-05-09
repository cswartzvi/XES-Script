#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to create all the necessary files to run the following XES Programs:
# 1)diag_lambda
# 2)xes
# 3)tmsftaes
# 4)tmsftbroadaes
#
# IMPORTANT: This script is intended to be run from a PBS WITHIN the 
# the GW_OUTDIR that is currently being run 
# ---> IF NOT this will not work
#
# INPUT: 1) Current PBE Number (For the shift of the spectrum)
#        2) The Main directroy of the XES Program
#---------------------------------------------------------------------------
#TODO Check that the programs exist and have these names
use warnings;
use strict;
use Cwd 'cwd';
use FindBin qw($Bin);

require "$Bin/read_variables.pm";
require "$Bin/Scripts/xml_tag.pm";

#Current PBE number 
my $PBEcount = shift @ARGV;

#Main directory of the XES Program
my $home = "$Bin/../"; 

#Root Output Directory -> Make CHMD outdir
my $cur_dir = cwd();

#---------------------------------------------------------
# Read in input-file.in namelist (Created by gs)
# IMPORTANT: This script is run INSIDE THE GW_OUTDIR
#---------------------------------------------------------
if (! -e '../input-file.in'){
   die " ERROR Input File Not Specified : $!";
}
my %var = &read_variables(0, '../input-file.in');
#---------------------------------------------------------

#******************************************************************************
# diag_lambda.x -> Calculates the diagonal of the lambda matrix
#
#  INPUT:   1) cp_lambda -> from cohsex (cp.x)
#           2) fort.11
#              total_bands val_bands Number-Gkvectors 
#
#  Output:  1) eig_dat -> Eigensvalues (WITH labels)
#           2) diagonalized lambda matrix
#******************************************************************************

    #---------------------------------------------------------
    #Make fort.11
    #---------------------------------------------------------
    my @gvec = &xml_tag($var{md_xml}, 'MAX_NUMBER_OF_GK-VECTORS'); 
    open my $fh_11, '>', 'fort.11' or die " ERROR: Cannot Open fort.11: $!";
    
    print $fh_11 "$var{tot_bands} $var{val_bands} $gvec[0]";
    close ($fh_11);
    #---------------------------------------------------------
    
    #Run Calculation
    #TODO Remove hard-code
    system ("$home/XES_src/diag_lambda.x");
    
    #******************************************************************************


#******************************************************************************
# xes.x -> Calculates the transition matrix
#
#  INPUT:   1) fort.10
#              volume_cell    ao             celldm2          celldm3
#              Num-Gkvectors  num_val_bands  num_cond_bands
#              kptx           kpty           kptz
#              Oxygenx        Oxygeny        Oxygenz
#           
#           2) eigv.dat -> remove the header and the val_bands lines of eig.dat (diag_lambda.x)
#
#           3) fort.11 -> same as before
#
#           3) fort.87  |
#           5) fort.88  | -> Oxygen core wavefunctions
#           6) fort.89  | 
#           7) fort.90  |
#           
#           8) g.dat -> from cohsex
#           9) cp_wf.dat -> from cohsex
#           10)diag_lambda.dat -> from diag_lambda.x
#
#  OUTPUT   1) fort.20  -> Main output file
#           2) tm_aes.dat -> raw transition matrix data
#******************************************************************************

   #---------------------------------------------------------
   # fort.10
   #---------------------------------------------------------
   @gvec = &xml_tag($var{md_xml}, 'MAX_NUMBER_OF_GK-VECTORS'); 
   my @alat = &xml_tag($var{md_xml}, 'LATTICE_PARAMETER'); 
   
   open my $fh_10, '>', 'fort.10' or die " ERROR: Cannot Open fort.10: $!";
   
   #TODO remove hard codes
   #atomic postion of excited atom
   open my $atoms_fh, '<', 'atomic_pos.dat' or die " ERROR: Cannot Open atomic_pos.dat: $!";
   my $exc_atom = <$atoms_fh>;
   $exc_atom =~ s/OO//;
   close($atoms_fh);
   
   #omega value (Volume of the cell)
   open my $omega_fh, '<', $var{md_dir}.'/omega.dat' or die " ERROR: Cannot Open omega.dat: $!";
   my $omega = <$omega_fh>;
   close($omega_fh);
   
   #Print fort.10
   select $fh_10;
   #TODO Add a check for the simple cubic cell
   print "$omega $alat[0] 1.0 1.0\n";
   print "$gvec[0] $var{val_bands} $var{con_bands}\n";
   #TODO Check for kpoints
   print "0.0 0.0 0.0\n";
   print $exc_atom;
   select STDOUT;
   close ($fh_10);
   #---------------------------------------------------------
   
   #---------------------------------------------------------
   # Copy all Oxygen core wavefunctions
   #---------------------------------------------------------
   #TODO Remove hard codes
   system("cp $home/Oxygen-1s-wf/fort.* .");
   #---------------------------------------------------------
   
   #---------------------------------------------------------
   # create the eigv.dat file
   #---------------------------------------------------------
   my $temp = $var{val_bands} + 1;
   system (" head -$temp eig.dat | tail -$var{val_bands} > eigv.dat "); 
   #---------------------------------------------------------
   
   #Run Calculation
   system ("$home/XES_src/xes.x");

#******************************************************************************

#******************************************************************************
# tmsftaes.x -> shift the spectrum before broadening
#
#  INPUT: 1) fort.13
#              number_val_bands  Total_Energy_First_Oxygen
#         2) fort.777
#              Current_total_energy
#         3) tm_aes.dat -> from xes.x
#
#  OUTPUT 1) tmsft_aes.dat -> Shifted transition matrix 
#******************************************************************************

   #---------------------------------------------------------
   # Create fort.13
   #---------------------------------------------------------
   #TODO remove this hard code   
   my $etot1 = `grep ! ../../Oxygen_1/$var{pbe_outdir}_$PBEcount/gw_${PBEcount}.in1 | gawk '{printf "%f", \$5/2}'`;

   open my $fh_13, '>', 'fort.13' or die " ERROR: Cannot Open fort.13: $!";
   print $fh_13 " $var{val_bands} $etot1";
   close ($fh_13);
   #---------------------------------------------------------

   #---------------------------------------------------------
   # Create fort.777
   #---------------------------------------------------------
   #TODO remove hard-code
   my $etot = `grep ! gw_1.out* | gawk '{printf "%f", \$5/2}'`;
   open my $fh_777, '>', 'fort.777' or die " ERROR: Cannot Open fort.777: $!";
   print $fh_777 " $etot";
   close ($fh_777);
   #---------------------------------------------------------

   #Run Calculation
   system ("$home/XES_src/tmsftaes.x");
#******************************************************************************


#******************************************************************************
# tmsftbroadaes.x -> broaden the spcturm
#
#  INPUT 1) fort.12
#           gauss_parameter   valence_bands
#        2) tmsft_aes.dat
#
#  OUTPUT 1) tmsftbroad_aes.dat --> shifted, broaden, transition matrix
#******************************************************************************
   
   #---------------------------------------------------------
   # create fort.12
   #---------------------------------------------------------
   open my $fh_12, '>', 'fort.12' or die " ERROR: Cannot Open fort.12: $!";
   #TODO remove hard codes
   print $fh_12 "0.4 $var{val_bands}";
   close ($fh_12);
   #---------------------------------------------------------

   #Run Calculation
   system ("$home/XES_src/tmsftbroadaes.x");
#******************************************************************************
