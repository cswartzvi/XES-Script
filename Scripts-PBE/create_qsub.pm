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

#This portion of the command script was generated automatically
#Edit it and you will get what you deserve

##the atoms-file header
cat > atoms.dat <<END
   $var{nat} 2 0
   $var{celldm}  0.00000000    0.00000000
   0.00000000    $var{celldm}  0.00000000
   0.00000000    0.00000000    $var{celldm} 

END

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
cd $var{gs_outdir}
echo "GS Calculation Started..." | tee $error_log
if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < gs.in > gs.out 2>> $error_log ; then
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
${scripts_dir}/create_chmd.pl $num
cd $var{chmd_outdir}
echo "CHMD Calculation Started..." | tee $error_log
if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < chmd.in > chmd.out 2>> $error_log; then
   echo "...CHMD Calculation Complete"
   cd ..
else
   echo "CHMD Calculation Failed (Check $error_log)!!"
   exit
fi
#***********************************************************

#***********************************************************
# PBE calculations
#***********************************************************
#Set up and run the PBE Calculations
${scripts_dir}/create_pbe.pl


for PBEcount in @{$var{xes_steps}}
do 

   #-----------------------------------
   #Change to the current directory
   cd $var{pbe_outdir}_\${PBEcount}
   #-----------------------------------
   
   echo ""
   echo "PBS Calculation: \$PBEcount" | tee $error_log


   #-----------------------------------
   #Submit the PWscf Calculation
   #-----------------------------------
   echo "PWscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < pbe_\${PBEcount}.in1 > pbe_\${PBEcount}.out1 2>> $error_log; then
     echo "...PWscf Calculation Complete"
   else
     echo"PWscf Calculation Failed (Check $error_log)!!!"
     exit
   fi
   #-----------------------------------

   #-----------------------------------
   #Submit PWnscf Calculation
   #Restart: $var{prefix}.save (From PWscf Calculation: no need to do anything)
   #-----------------------------------
      echo "PWnscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < pbe_\${PBEcount}.in2 > pbe_\${PBEcount}.out2 2>> $error_log; then
      echo "...PWnscf Calculation Complete"
   else
      echo "PWnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #Copy $var{prefix}.save to $var{prefix}_50.save 
   clean_copy $var{prefix}.save $var{prefix}_50.save
   #-----------------------------------

   #-----------------------------------
   #Submit CPnscf Calculation
   #Restart: $var{prefix}_50.save from the PWnscf Calulation
   #-----------------------------------
      echo "CPnscf Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < pbe_\${PBEcount}.in3 > pbe_\${PBEcount}.out3 2>> $error_log; then
      echo "...CPnscf Calculation Complete"
   else
      echo "CPnscf Calculation Failed (Check $error_log)!!"
      exit
   fi

   #-----------------------------------
   
   #-----------------------------------
   #Submit CPnscf Print-Out Calculation
   #Restart: $var{prefix}_50.save from the first CPnscf Calulation
   #-----------------------------------
      echo "CPnscf Print-Out Calculation Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < pbe_\${PBEcount}.in4 > pbe_\${PBEcount}.out4 2>> $error_log; then
      echo "...CPnscf Print-Out Calculation Complete"
   else
      echo "CPnscf Print-Out Calculation Failed (Check $error_log)!!"
      exit
   fi
   #-----------------------------------

   #-----------------------------------
   #Gen projections
   #-----------------------------------

   tail -$var{nat} pbe_\${PBEcount}.in1 >> atoms.dat
   sed -i -e 's/OO/16/g' -e 's/O/8/g' -e 's/H/1/g' atoms.dat

      echo "General Projections Started..." | tee -a $error_log
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gen_proj} < xsf.in > xsf.out 2>> $error_log; then
      echo "...General projections Complete"
   else
      echo "General Projections Failed (Check $error_log)!!"
      exit
   fi

   \$wave_dir=wavefunctions
   if [ ! -d \$wave_dir ];then
      mkdir \$wave_dir
   fi
   mv KS_* WAN_* \$wave_dir
   #-----------------------------------


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
select STDIN;
close($submit_fh);

return $submit_script;
}
1;
