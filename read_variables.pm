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

   #Set Defaults for the main variables
   my %var = (
      config_start      => 1,
      config_stop       => 64,
      procs             => '',
      procs_gw          => '',
      prefix            => '',
      numO              => 64,
      numH              => 128,
      celldm            => '',
      pseudo_dir        => '',
      md_dir            => '', 
      md_xml            => '',
      gs_template       => '',
      gs_outdir         => 'Data-Files_GS',
      gs_qe             => '',
      chmd_outdir       => 'Data_Files_CHMD',
      chmd_template     => '',
      chmd_steps        => '150',
      chmd_iprint       => '30',
      chmd_qe           => '',
      submit_template   => '',
      para_prefix       => '',
   );

   #Total Atoms
   $var{nat} = $var{numO} + $var{numH};

   #Loop through the input file
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

   print " Input Check:\n";
   #TODO Check to make sure none of the variables are undefined
   while (my ($key, $value) = each %var){
      #TODO Remove input check!
      print "  \$var\{$key\} => $value \n"; 
   }
 
   close($fh);
   return %var;
}
1;
