#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to create the qsub PBS script for individual excited Atoms 
# 
#
# INPUT: 1) Number of the currently excited atom 
#        2) Hash ref for var
#        3) Current Directory for the excited atom
#        4) $home the pathname of the of the main Program directory
#        5) $exe_home the pathname of the of the scripts directory
#
# OUTPUT: 1)
#----------------------------------------------------------------------------

use warnings;
use strict;
use File::Copy qw(copy);
use Cwd 'cwd';

sub create_qsub{

   #number of the currently excited atom
   my $num = shift @_;

   #Main variable Hash
   my $var_ref = shift @_;
   my %var = %$var_ref;

   #Absolute Pathname where the PBS File will be ran
   my $current_dir = shift @_;
   my $pathname = cwd().'/'.$current_dir;

   #Pathname of the XES_Program directory
   my $home = shift @_; 

   #Pathname of the scripts directory (because this current script will end before the 
   #the next is executed
   my $exe_home = shift @_; 

   #open and read in the submit_template
   open my $submit_template_fh, '<', $var{submit_template} 
      or die " ERROR: Cannot Open File $var{submit_template} :$!"; 
   my @template = <$submit_template_fh>;

   #TODO Add Error Checks fo the PBS File

   #open Actual Submit File
   my $submit_script = $current_dir.'/'.'submit.sh';
   open my $submit_fh, '>', $submit_script
      or die " ERROR: Cannot Open File $submit_script : $!";
   select $submit_fh;

   #Start the copying process
   print  @template;

   #Error File Name
   my $error_log = 'error.log';

#------------------------------------------------------
#Create the Here-Document
#------------------------------------------------------
print <<EOF;

#This portion of the command script was generated automatically
#Edit it and you will get what you deserve

function clean_copy {
  if [ -d \$2 ]; then /bin/rm -r \$2; fi
  if [ ! -d \$2 ]; then mkdir \$2; fi
  cp -r \$1/* \$2
}

cd $pathname

#***********************************************************
#Run the Groundstate Calculation
#***********************************************************
echo "GS Calculation Started..." | tee $error_log
cd $var{gs_outdir}
if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < gs.in > gs.out 2> $error_log ; then
   echo "...GS Calculation Complete"
   cd ..
else
   echo "GS Calculation Failed (Check $error_log)!!"
   ecit
fi
#***********************************************************

#***********************************************************
# CHMD Calculations
#***********************************************************
${exe_home}/create_chmd.pl $num
echo "CHMD Calculation Started..." | tee $error_log
cd $var{chmd_outdir}
if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < chmd.in > chmd.out 2> $error_log; then
   echo "...CHMD Calculation Complete"
   cd ..
else
   echo "CHMD Calculation Failed (Check $error_log)!!"
   exit
fi
#***********************************************************

#***********************************************************
# GW calculations
#***********************************************************
#Set up and run the GW Calculations
${exe_home}/create_gw.pl


GWcount=1
while [ 1 ]; do

   echo ""
   echo "GW Calculation: \$GWCount" | tee $error_log

   #-----------------------------------
   #Change to the current directory
   cd $var{gw_outdir}_\${GWcount}
   #-----------------------------------
   
   #Check to see if this file is actually there
   if [[ ! -e gw_1.in\${GWcount} ]]; then
      break
   fi

   #-----------------------------------
   #Submit the PWscf Calculation
   #-----------------------------------
   echo "PWscf Calculation Started..." | tee $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < gw_1.in\${GWcount} > gw_1.out\${GWcount} 2> $error_log; then
     echo "...PWscf Calculation Complete"
   else
     echo"PWscf Calculation Failed (Check $error_log)!!!"
     exit
   fi
   
   #Copy the results from $var{prefix}.save to save $var{prefix}_50.save for the CP Ground-State Calculation
   #this will leave the $var{prefix} unchanged for the PW NSCF Calculatiosn later (NOT the GW Calculation)
   clean_copy $var{prefix}.save $var{prefix}_50.save
   #-----------------------------------

   #-----------------------------------
   #Submit the CP Ground State
   #Restart: $var{prefix}_50.save (Copied from PW calculation)
   #-----------------------------------
      echo "CP Calculation Started..." | tee $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gw_qe} < gw_2.in\${GWcount} > gw_2.out\${GWcount} 2> $error_log; then
      echo "...CP Calculation Complete"
   else
      echo "CP Calculation Failed (Check $error_log)!!"
      exit
   fi

   #Copy the results into $var{prefix}_36.save (For the GW Calculation)
   clean_copy $var{prefix}_50.save $var{prefix}_36.save

   #Copy the valence band wannier centers into fort.408
   #TODO Remove this hard-code for the valence bands
   tail -$var{val_bands} $var{prefix}.wfc > fort.408
   #-----------------------------------

   #-----------------------------------
   #Submit PWnscf Calculation
   #Restart: $var{prefix}.save (From PWscf Calculation: no need to do anything)
   #-----------------------------------
      echo "PWnscf Calculation Started..." | tee $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < gw_3.in\${GWcount} > gw_3.out\${GWcount} 2> $error_log; then
      echo "...PWnscf Calculation Complete"
   else
      echo "PWnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #Copy $var{prefix}.save to $var{prefix}_50.save (NOT for the GW Caluclation)
   clean_copy $var{prefix}.save $var{prefix}_50.save
   #-----------------------------------

   #-----------------------------------
   #Submit CPnscf Calculation
   #Restart: $var{prefix}_50.save from the PWnscf Calulation
   #-----------------------------------
      echo "CPnscf Calculation Started..." | tee $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gw_qe} < gw_4.in\${GWcount} > gw_4.out\${GWcount} 2> $error_log; then
      echo "...CPnscf Calculation Complete"
   else
      echo "CPnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #copy the total wannier centers to fort.407
   tail -$var{tot_bands} $var{prefix}.wfc > fort.407
   #-----------------------------------
   
   #-----------------------------------
   #GW Calculaiton
   #Restart: $var{prefix}_50.save   --> Total Charge Density
   #         $var{prefix}_36.save   --> Valence Charge Density
   #         fort.407               --> Total wannier centers (valence and conduction)
   #         fort.408               --> Valence Wannier Centers
   #-----------------------------------
   echo "GW Calculation Started ..." | tee $error_log
   if $var{para_prefix} $var{para_flags} $var{procs_gw} $var{gw_qe} < gw_5.in\${GWcount} > gw_5.out\${GWcount} 2> $error_log; then
      echo "GW Calculation Complete"
   else
      echo "GW Calculation Failed (Check $error_log)!!"
      exit
   fi
   #-----------------------------------

   #-----------------------------------
   # Run the XES
   #-----------------------------------
   echo "XES Calculations Started ..." | tee $error_log
   if ${exe_home}/run_xes.pl ${home} 2> $error_log; then
      echo "XES Calculations Complete"
   else
      echo "XES Calculations Failed (Check $error_log)!!"
   fi
   #-----------------------------------

   #-----------------------------------
   # Leave Current Directroy
   #-----------------------------------
   cd ..
   #-----------------------------------

   GWcount=\$((\$GWcount + 1))
done
#***********************************************************

EOF
#------------------------------------------------------
select STDIN;
close($submit_fh);
}
1;
