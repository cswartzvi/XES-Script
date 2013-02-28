#! /usr/bin/perl
#------------------------------------------------------------------
# This Module will read in the main set-up variables in  
# a Fortran-like namelist and then pass a hash back
# to the calling routine
#
#  Example:
#  Key = Value
#
# INPUT:    1) Filename of the input
#
# OUTPUT:   1) Hash (var) of main variables
#------------------------------------------------------------------

use warnings;
use strict;

sub read_variables{

   #for the appending of the templates
   #first time = 1, after that = 0
   my $append = shift @_;

   #Get the filename
   my ($input_file) = @_;
   open my $fh, '<', $input_file or die " ERROR: Cannot Open $input_file : $!";

   #------------------------------------------------------
   #Set Defaults for the main variables
   #TODO Remove some of these and read directly form output file
   #------------------------------------------------------
   my %var = (
      config_start         => 1,                   #Starting Excited Oxygen
      config_stop          => '',                  #Ending Excited Oxygen
      procs                => '',                  #Number of normal Processor (PW, CP, PWnscf, CPnscf)
      procs_gw             => '',                  #Number of GW Processors
      prefix               => '',                  #Prefix for the QE input Files
      numO                 => '',                  #Number of Oxygens
      numH                 => '',                  #Number of Hydrogens
      val_bands            => '',                  #Number of Valence Bands (used in GS, CHMD, PW, and CP)
      con_bands            => '',                  #Number of Conduction Bands (used in PWnscg, CPnscf, GW)
      celldm               => '',                  #Lattice constant (From MD Simulation)
      pseudo_dir           => '',                  #Pseudopotential Directory
      template_dir         => '',                  #Directory for ALL Templates
      md_dir               => '',                  #Directory of the Original MD Simulation
      md_xml               => '',                  #XMl File from the Original MD SImulation
      gs_template          => '',                  #Excited Oxygen GS Template
      gs_outdir            => 'Data-Files_GS',     #outdir in QE files (GS)
      chmd_template        => '',                  #Excited Oxygen CHMD Template
      chmd_outdir          => 'Data-Files_CHMD',   #outdir in QE files (CHMD)
      gw_pw_template       => '',                  #GW template: PW Calculation (1/5)
      gw_cp_template       => '',                  #GW template: CP Calculation (2/5) 
      gw_pwnscf_template   => '',                  #GW template: PWnscf Calculation (3/5)
      gw_cpnscf_template   => '',                  #GW template: CPnscf Calculation (4/5)
      gw_template          => '',                  #GW template: GW-lf Calculation (5/5)
      gw_outdir            => 'Data-Files_GW',     #outdir for QE files (All GWs)
      submit_template      => '',                  #submit bash script (PBS ..)
      para_prefix          => '',                  #Command to execute parallel run (aprun, mpirun,...)
      para_flags           => '',                  #Parallel command Flags (-n or -np MUST be last)
      pw_qe                => '',                  #Path to QE PW executable
      cp_qe                => '',                  #Path to QE CP executable
      gw_qe                => '',                  #Path to QE GW executable
   );
   #------------------------------------------------------


   #------------------------------------------------------
   #Loop through the input file
   #------------------------------------------------------
   while (defined(my $line = <$fh>)){
      chomp($line);

      #Split on the equal sign
      if (my @temp = split /\s*=\s*/, $line) {

         while ( my ($key, $value) = each %var ) {
            if ($temp[0] eq $key){
               $var{$key} = $temp[1];
               $var{$key} =~ s/(\s+|,)//;
            }
         }

      }

   }
   #------------------------------------------------------

   #------------------------------------------------------
   # Add a few values
   #------------------------------------------------------
   #TODO check the para_flags element
   #Add templates Directory to all templates!
   #if $append = 0 (first time through)
   if ($append){
      while ( my($key, $value) = each %var){
         if ($key =~ /.*_template/){
            $var{$key} = $var{template_dir}.'/'.$var{$key};
         }
      }
   }
   #Total Bands
   $var{tot_bands} = $var{val_bands} + $var{con_bands};
   #Total Atoms
   $var{nat} = $var{numO} + $var{numH};
   #------------------------------------------------------

   #------------------------------------------------------
   # Input Check 
   # TODO Remove this Input Check
   #------------------------------------------------------
   print " Input Check:\n";
   #TODO Check to make sure none of the variables are undefined
   while (my ($key, $value) = each %var){
      #TODO Remove input check!
      print "  \$var\{$key\} => $value \n"; 
   }
   #------------------------------------------------------
 
   close($fh);
   return %var;
}
1;
