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

   #Get the filename
   my ($input_file) = @_;
   open my $fh, '<', $input_file or die " ERROR: Cannot Open $input_file : $!";

   #------------------------------------------------------
   #Set Defaults for the main variables
   #TODO Remove some of these and read directly form output file
   #------------------------------------------------------
   my %var = (
      config_start         => 1,
      config_stop          => 64,
      procs                => '',
      procs_gw             => '',
      prefix               => '',
      numO                 => 64,
      numH                 => 128,
      val_bands            => 256,
      con_bands            => 256,
      celldm               => '',
      pseudo_dir           => '',
      md_dir               => '', 
      md_xml               => '',
      gs_template          => '',
      gs_outdir            => 'Data-Files_GS',
      chmd_outdir          => 'Data-Files_CHMD',
      chmd_template        => '',
      gw_pw_template       => '', 
      gw_pwnscf_template   => '', 
      gw_cp_template       => '', 
      gw_cpnscf_template   => '', 
      gw_template          => '',
      gw_outdir            => 'Data-Files_GW',
      submit_template      => '',
      para_prefix          => '',
      para_flags           => '',
      pw_qe                => '',
      cp_qe                => '',
      gw_qe                => '',
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
