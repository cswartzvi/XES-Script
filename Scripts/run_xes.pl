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
# INPUT: 1) the Main directroy of the XES Program
#---------------------------------------------------------------------------
#TODO Check that the programs exist and have these names
use warnings;
use strict;
use Cwd 'cwd';

require '/global/homes/c/cswartz/Scripts/XES_Script/Scripts/read_variables.pm';
require '/global/homes/c/cswartz/Scripts/XES_Script/Scripts/xml_tag.pm';

#Main directory of the XES Program
my $home = shift @ARGV;

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

#---------------------------------------------------------
#diag_lambda
#
#  INPUT:   1) cp_lambda -> from cohsex (cp.x)
#           2) fort.11
#              total_bands val_bands Number-Gkvectors 
#
#  Output:  1) eig_dat -> Eigensvalues (WITH labels)
#           2) diagonalized lambda matrix
#---------------------------------------------------------
#Make fort.11
open my $fh_11, '>', 'fort.11' or die " ERROR: Cannot Open fort.11: $!";
#TODO Fix the neative issue with split
my @gvec = &xml_tag($var{md_xml}, 'MAX_NUMBER_OF_GK-VECTORS'); 
print $fh_11 "$var{tot_bands} $var{val_bands} $gvec[1]";

#TODO Remove hard-code
system ("$home/XES_src/diag_lambda.x");

#---------------------------------------------------------

