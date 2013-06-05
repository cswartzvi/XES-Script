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

function clean_copy {
  if [ -d \$2 ]; then /bin/rm -r \$2; fi
  if [ ! -d \$2 ]; then mkdir \$2; fi
  cp -r \$1/* \$2
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
# XES (GW) calculations
#***********************************************************
#Set up and run the XES (GW) Calculations
$scripts_dir/create_gw.pl


for XEScount in @{$var{xes_steps}}
do 


   #-----------------------------------
   #Change to the current directory
   cd $var{xes_outdir}_\${XEScount}
   #-----------------------------------
   
   echo ""
   echo "XES (GW) Calculation: \$XEScount" | tee $error_log


   #-----------------------------------
   #1) Submit the PWscf Calculation
   #-----------------------------------
   echo "PWscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < ${inout}_\${XEScount}.in1 > ${inout}_\${XEScount}.out1 2>> $error_log; then
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
   #2) Submit CP Groundstate Calculation
   #Restart: $var{prefix}_50.save (From PWscf Calculation)
   #-----------------------------------
      echo "CP Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < ${inout}_\${XEScount}.in2 > ${inout}_\${XEScount}.out2 2>> $error_log; then
      echo "...CP Calculation Complete"
   else
      echo "CP Calculation Failed (Check $error_log)!!"
      exit
   fi

   #Copy the results into $var{prefix}_36.save (For the GW Calculation)
   clean_copy $var{prefix}_50.save $var{prefix}_36.save

   #Copy the valence band wannier centers into fort.408
   tail -$var{val_bands} $var{prefix}.wfc > fort.408
   #-----------------------------------

   #-----------------------------------
   #3) Submit PWnscf Calculation
   #Restart: $var{prefix}.save (From PWscf Calculation: no need to do anything)
   #-----------------------------------
      echo "PWnscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < ${inout}_\${XEScount}.in3 > ${inout}_\${XEScount}.out3 2>> $error_log; then
      echo "...PWnscf Calculation Complete"
   else
      echo "PWnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #Copy $var{prefix}.save to $var{prefix}_50.save (NOT for the GW Caluclation)
   clean_copy $var{prefix}.save $var{prefix}_50.save
   #-----------------------------------
   
   #-----------------------------------
   #4) Submit CPnscf Calculation
   #Restart: $var{prefix}_50.save from the PWnscf Calulation
   #-----------------------------------
      echo "CPnscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gw_qe} < ${inout}_\${XEScount}.in4 > ${inout}_\${XEScount}.out4 2>> $error_log; then
      echo "...CPnscf Calculation Complete"
   else
      echo "CPnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #copy the total wannier centers to fort.407
   tail -$var{tot_bands} $var{prefix}.wfc > fort.407
   #-----------------------------------

   #*******************************************************************
   # The following is for the Gen Projections print-out
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
   #4b)Submit CPnscf Print-Out Wavefunction Calculation 
   #Restart: $var{prefix}_50.save from the CPnscf Calulation
   #-----------------------------------
   echo "CPnscf Print-Out Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gw_qe} < ${inout}_\${XEScount}.in4b > ${inout}_\${XEScount}.out4b 2>> $error_log; then
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
   #4) Submit GW Local Field Calculation
   #Restart: $var{prefix}_50.save   --> Total Charge Density
   #         $var{prefix}_36.save   --> Valence Charge Density
   #         fort.407               --> Total wannier centers (valence and conduction)
   #         fort.408               --> Valence Wannier Centers
   #-----------------------------------
      echo "GW Local Field Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{gw_procs} $var{gw_qe} < ${inout}_\${XEScount}.in5 > ${inout}_\${XEScount}.out5 2>> $error_log; then
      echo "...GW Local Field Calculation Complete"
   else
      echo "GW Local Field Calculation Failed (Check $error_log)!!"
      exit
   fi
   #-----------------------------------

   #-----------------------------------
   # Run the XES
   #-----------------------------------
   echo "XES Calculations Started ..." | tee -a $error_log
   if ${scripts_dir}/run_xes.pl \$XEScount 2>> $error_log; then
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
