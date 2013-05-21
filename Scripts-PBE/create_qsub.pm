#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to create the qsub PBS script for individual excited Atoms 
# 
#
# INPUT: 1) Number of the currently excited atom 
#        2) Hash ref for var
#        3) Current Directory for the excited atom
#
# OUTPUT: 1)
#----------------------------------------------------------------------------

use warnings;
use strict;
use File::Copy qw(copy);
use Cwd 'cwd';
use FindBin qw($Bin);


sub create_qsub{

   #Main variables
   require "$Bin/mainvar.pl";
   our ($atomic_pos_file, $gs_in, $gs_out, $chmd_in, $chmd_out, $inout, $xsf_in, $xsf_out);

   #---------------------------------------------
   # Inputs
   #---------------------------------------------
   #number of the currently excited atom
   my $num = shift @_;

   #Main variable Hash
   my $var_ref = shift @_;
   my %var = %$var_ref;

   #Absolute Pathname where the PBS File will be ran
   my $current_dir = shift @_;
   my $pathname = cwd().'/'.$current_dir;
   #---------------------------------------------

   #Direcotroy of the XES Programs
   my $xes_dir = "$Bin/../XES_src";

   #Pathname of the scripts directory (because this current script will end before the 
   #the next is executed
   my $scripts_dir = "$Bin";

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

   #Output FIle Name
   my $output_file = $pathname.'/output.log';
   #Error File Name
   my $error_log = 'error.log';

#------------------------------------------------------
#Create the Here-Document
#------------------------------------------------------
print <<EOF;

####################################################################
#-------------------------------------------------------------------
#This portion of the command script was generated automatically
#Edit it and you will get what you deserve
#-------------------------------------------------------------------
####################################################################

function clean_move {
  if [ -d \$2 ]; then /bin/rm -r \$2; fi
  if [ ! -d \$2 ]; then mkdir \$2; fi
  #cp -r \$1/* \$2
  mv \$1 \$2
}

#Redirect all STDOUT to file
exec 1> $output_file

cd $pathname


#***********************************************************
#Run the Groundstate Calculation
#***********************************************************
if [ "$var{gs_skip}" -eq "0" ]; then
   cd $var{gs_outdir}
   echo "GS Calculation Started..." | tee $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < $gs_in > $gs_out 2>> $error_log ; then
      echo "...GS Calculation Complete"
      cd ..
   else
      echo "GS Calculation Failed (Check $error_log)!!"
      exit
   fi
else
   echo "GS Calculation is Skipped!!"
fi
#***********************************************************

#***********************************************************
# CHMD Calculations
#***********************************************************
$scripts_dir/create_chmd.pl $num
if [ \$? -ne "1" ]; then
   cd $var{chmd_outdir}
   echo "CHMD Calculation Started..." | tee $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < $chmd_in > $chmd_out 2>> $error_log; then
      echo "...CHMD Calculation Complete"
      cd ..
   else
      echo "CHMD Calculation Failed (Check $error_log)!!"
      exit
   fi
else
   echo "CHMD Skipped!!"
fi
#***********************************************************

#***********************************************************
# PBE calculations
#***********************************************************
#Set up and run the PBE Calculations
$scripts_dir/create_pbe.pl


for PBEcount in @{$var{xes_steps}}
do 


   #-----------------------------------
   #Change to the current directory
   cd $var{pbe_outdir}_\${PBEcount}
   #-----------------------------------
   
   echo ""
   echo "PBE Calculation: \$PBEcount" | tee $error_log


   #-----------------------------------
   #1) Submit the PWscf Calculation
   #-----------------------------------
   echo "PWscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < ${inout}_\${PBEcount}.in1 > ${inout}_\${PBEcount}.out1 2>> $error_log; then
     echo "...PWscf Calculation Complete"
   else
     echo"PWscf Calculation Failed (Check $error_log)!!!"
     exit
   fi
   #-----------------------------------

   #-----------------------------------
   #2) Submit PWnscf Calculation
   #Restart: $var{prefix}.save (From PWscf Calculation: no need to do anything)
   #-----------------------------------
      echo "PWnscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < ${inout}_\${PBEcount}.in2 > ${inout}_\${PBEcount}.out2 2>> $error_log; then
      echo "...PWnscf Calculation Complete"
   else
      echo "PWnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #Copy $var{prefix}.save to $var{prefix}_50.save 
   clean_move $var{prefix}.save $var{prefix}_50.save
   #-----------------------------------

   #-----------------------------------
   #3) Submit CPnscf Calculation
   #Restart: $var{prefix}_50.save from the PWnscf Calulation
   #-----------------------------------
      echo "CPnscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_mod_qe} < ${inout}_\${PBEcount}.in3 > ${inout}_\${PBEcount}.out3a 2>> $error_log; then
      echo "...CPnscf Calculation Complete"
   else
      echo "CPnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #-----------------------------------
   
   #-----------------------------------
   #TODO This is currently a hack: the QE needs to be modified to do this at the ned of the run
   #4) Submit CPnscf Print cp_wf.dat 
   #Restart: $var{prefix}_50.save from the first CPnscf Calulation
   #-----------------------------------
   sed -i  -e 's/\\(nsteps\\s\\+=\\s\\+\\).*/\\1 1/g' pbe_\${PBEcount}.in3
      echo "CPnscf Calculation 2 Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_mod_qe} < ${inout}_\${PBEcount}.in3 > ${inout}_\${PBEcount}.out3b 2>> $error_log; then
      echo "...CPnscf Calculation Complete"
   else
      echo "CPnscf Calculation Failed (Check $error_log)!!"
      exit
   fi
   #-----------------------------------

   #*******************************************************************
   # The following is for the Gen Porjections print-out
   #*******************************************************************
   #the atoms-file header
   cat > atoms.dat <<END
      $var{nat} 2 0
      $var{celldm}  0.00000000    0.00000000
      0.00000000    $var{celldm}  0.00000000
      0.00000000    0.00000000    $var{celldm} 

END

   cat > submit-wave-print.sh <<END
   #-----------------------------------
   #5)Submit CPnscf Print-Out Wavefunction Calculation 
   #Restart: $var{prefix}_50.save from the second CPnscf Calulation
   #-----------------------------------
   echo "CPnscf Print-Out Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_mod_qe} < ${inout}_\${PBEcount}.in4 > ${inout}_\${PBEcount}.out4 2>> $error_log; then
      echo "...CPnscf Print-Out Calculation Complete"
   else
      echo "CPnscf Print-Out Calculation Failed (Check $error_log)!!"
   fi
   #-----------------------------------

   #-----------------------------------
   #Gen projections
   #-----------------------------------

   cat $atomic_pos_file >> atoms.dat
   sed -i -e 's/OO/16/g' -e 's/O/8/g' -e 's/H/1/g' atoms.dat

   echo "General Projections Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gen_proj} < $xsf_in > $xsf_out 2>> $error_log; then
      echo "...General projections Complete"
   else
      echo "General Projections Failed (Check $error_log)!!"
   fi

   wave_dir=wavefunctions
   if [ ! -d \\\$wave_dir ];then
      mkdir \\\$wave_dir
   fi
   mv KS_* WAN_* \\\$wave_dir
END

   #-----------------------------------
   #Run the Gen-Projections
   #-----------------------------------
   if [ "$var{gen_proj_run}" -ne "0" ]; then
      bash submit-wave-print.sh
   fi
   #-----------------------------------
   #*******************************************************************


   #-----------------------------------
   # Run the XES
   #-----------------------------------
   echo "XES Calculations Started ..." | tee -a $error_log
   if ${scripts_dir}/run_xes.pl \$PBEcount 2>> $error_log; then
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

done
#***********************************************************

EOF
#------------------------------------------------------
select STDOUT;
close($submit_fh);

return $submit_script;
}
1;
