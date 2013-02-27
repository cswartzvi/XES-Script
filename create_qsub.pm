#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to create the qsub PBS script for individual excited Atoms 
# 
#
# INPUT: 1) Number of the currently excited atom 
#        2) Hash ref for var
#        3) Current Directory for the excited atom
#        4) $exe_home the pathname of the of the scripts directory
#
# OUTPUT: 1)
#----------------------------------------------------------------------------

use warnings;
use strict;
use 5.012;
use File::Copy qw(copy);
use Cwd 'cwd';

sub create_qsub{

   #number of the currently excited atom
   my $num = shift @_;

   #Main variable
   my $var_ref = shift @_;
   my %var = %$var_ref;

   #Absolute Pathname
   my $current_dir = shift @_;
   my $pathname = cwd().'/'.$current_dir;

   #Pathname of the scripts directory
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
if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < gs.in > gs.out; then
   echo "GS Calculation Complete..."
else
   echo "GS Calculation Failed!!"
   ecit
fi
#***********************************************************

#***********************************************************
# CHMD Calculations
#***********************************************************
${exe_home}/create_chmd.pl $num
if $var{para_prefix} $var{para_flags} $var{procs} $var{cp_qe} < gs.in > gs.out; then
   echo "CHMD Calculation Complete..."
else
   echo "CHMD Calculation Failed!!"
   exit
fi
#***********************************************************

#***********************************************************
# GW calculations
#***********************************************************
#Set up and run the GW Calculations
${exe_home}/create_gw.pl


GWcount=1
while 1; do

   echo ""
   echo "GW Calculation: \$GWCount"

   #Check to see if this file is actually there
   if [[ ! -e gw_1.in\${GWcount} ]]; then
      break
   fi
   
   #-----------------------------------
   #Submit the PWscf Calculation
   #-----------------------------------
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < gw_1.in\${GWcount} > gw_1.out\${GWcount} ; then
     echo "PWscf Calculation Complete..."
   else
     echo"PWscf Calculation Failed!!!"
     exit
   fi
   
   #Copy the results from $var{prefix}.save to save $var{prefix}_50.save for the CP Ground-State Calculation
   #this will leave the $var{prefix} unchanged for the PW NSCF Calculatiosn later (NOT the GW Calculation)
   clean_copy $var{gw_outdir}/$var{prefix}.save $var{gw_outdir}/$var{prefix}_50.save
   #-----------------------------------

   #-----------------------------------
   #Submit the CP Ground State
   #Restart: $var{prefix}_50.save (Copied from PW calculation)
   #-----------------------------------
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gw_qe} < gw_2.in\${GWcount} > gw_2.out\${GWcount}; then
      echo "CP Calculation Complete..."
   else
      echo "CP Calculation Failed!!"
      exit
   fi

   #Copy the results into $var{prefix}_36.save (For the GW Calculation)
   clean_copy $var{gw_outdir}/$var{prefix}_50.save $var{gw_outdir}/$var{prefix}_36.save

   #Copy the valence band wannier centers into fort.408
   #TODO Remove this hard-code for the valence bands
   tail -512 $var{gw_outdir}/$var{prefix}.wfc > fort.407
   #-----------------------------------

   #-----------------------------------
   #Submit PWnscf Calculation
   #Restart: $var{prefix}.save (From PWscf Calculation: no need to do anything)
   #-----------------------------------
   if $var{para_prefix} $var{para_flags} $var{procs} $var{pw_qe} < gw_3.in\${GWcount} > gw_3.out\${GWcount}; then
      echo "PWnscf Calculation Complete..."
   else
      echo "PWnscf Calculation Failed!!"
      exit
   fi

   #Copy $var{prefix}.save to $var{prefix}_50.save (NOT for the GW Caluclation)
   clean_copy $var{gw_outdir}/$var{prefix}.save $var{gw_outdir}/$var{prefix}_50.save
   #-----------------------------------

   #-----------------------------------
   #Submit CPnscf Calculation
   #Restart: $var{prefix}_50.save from the PWnscf Calulation
   #-----------------------------------
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gw_qe} < gw_4.in\${GWcount} > gw_4.out\${GWcount}; then
      echo "CPnscf Calculation Complete..."
   else
      echo "CPnscf Calculation Failed!!"
      exit
   fi

   #copy the total wannier centers to fort.407
   #TODO Remove this hard-code for the total bands
   tail -256 $var{gw_outdir}/$var{prefix}.wfc > fort.408 
   #-----------------------------------
   
   #-----------------------------------
   #GW Calculaiton
   #Restart: $var{prefix}_50.save   --> Total Charge Density
   #         $var{prefix}_36.save   --> Valence Charge Density
   #         fort.407               --> Total wannier centers (valence and conduction)
   #         fort.408               --> Valence Wannier Centers
   #-----------------------------------
   if $var{para_prefix} $var{para_flags} $var{procs} $var{gw_qe} < gw_4.in\${GWcount} > gw_4.out\${GWcount}; then
      echo "GW Calculation Complete ..."
   else
      echo "GW Calculation Failed!!"
      exit
   fi
   #-----------------------------------

   GWcount=\$((\$GWcount + 1))
done
#***********************************************************

${exe_home}/create_xes.pl

EOF
#------------------------------------------------------
select STDIN;
close($submit_fh);
}
1;
