#! /usr/bin/perl
#

use strict;
use warnings;


our $main_input_file;                                 #Main input-file read in the first script

our $input_file;
$input_file = 'input-file.dat';                       #Input that will be created and then reused by all scripts

our $init_atomic_pos_file;                            
$init_atomic_pos_file = 'init_atomic_pos.dat';        #Name of the initial postion file inside each Oxygen_ directory

our $atomic_pos_file;                            
$atomic_pos_file = 'atomic_pos.dat';             #Name of the postion file inside each PBE_ directory

#---------------------------------------------------------------------------------------
# Calculation Names
#---------------------------------------------------------------------------------------
our ($gs_in, $gs_out);
$gs_in    =  'gs.in';                                  #GroundState in
$gs_out   =  'gs.out';                                 #GroundStat out

our ($chmd_in, $chmd_out);
$chmd_in    =  'chmd.in';                              #Core Hole Molecular Dynamics in
$chmd_out   =  'chmd.out';                             #Core Hole Molecular Dynamcis out

our ($xsf_in, $xsf_out);
$xsf_in = 'xsf.in';                                    #Gen Projections Input
$xsf_out = 'xsf.out';                                  #Gen Projections Output


#TODO make these root names non-hard coded
our $inout;
$inout = 'pbe';                                       #Main Input/Output Root
