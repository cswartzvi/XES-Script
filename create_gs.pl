#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to convert to take the gs.in template and create multiple 
# Ground-State Files with Different Atoms being excited
#
# INPUT: 1) 
#
# OUTPUT: 1)
#----------------------------------------------------------------------------

use warnings;
use strict;
use 5.012;
use File::Copy qw(copy);

#TODO set this require by a small bash 'configure' script
require '/home/charles/Desktop/Research/XES_Project/Scripts/read_variables.pm';
require '/home/charles/Desktop/Research/XES_Project/Scripts/alter_template.pm';
require '/home/charles/Desktop/Research/XES_Project/Scripts/create_qsub.pm';
my $exe_home = '/home/charles/Desktop/Research/XES_Project/Scripts';

#---------------------------------------------------------
# Read in STDIN namelist 
#---------------------------------------------------------
my $input_file = shift @ARGV ;
if (! $input_file){
   die " ERROR Input File Not Specified : $!";
}
my %var = &read_variables($input_file);
#---------------------------------------------------------

#---------------------------------------------------------
# Parse the xml Data-File from the MD Simulation for STEP0 and STEPM
#  xml_parse.pl <- data-file-path output-dir (list of tags) ->  list-of-tags-files
#---------------------------------------------------------
#TODO Convert this in to a module
my $test = system("/home/charles/Desktop/Research/XES_Project/Scripts/xml_data_parse.pl $var{md_xml} $var{md_dir} taui force stau svel ht") ;
if ($test != 0) { die " ERROR: xml_data_parse.pl failed to execute!"};
#---------------------------------------------------------

#---------------------------------------------------------
# Convert stau to tau from the previous MD Simulation
#  -> stau_to_tau.pl path-to-ht path-to-stau md_dir
#---------------------------------------------------------
#TODO Convert this in to a module
system(" /home/charles/Desktop/Research/XES_Project/Scripts/stau_to_tau.pl $var{md_dir}/ht_STEP0.dat $var{md_dir}/stau_STEP0.dat $var{md_dir}");
if ($test != 0) { die " ERROR: stau_to_tau.pl failed to execute!"};

#Open the atoms.dat created by stau_to_tau read into an array
open my $atoms_fh, '<', $var{md_dir}.'/atoms.dat' or die " ERROR: Cannot Open File $!";
my @atoms = <$atoms_fh>;
close($atoms_fh);
#---------------------------------------------------------

#---------------------------------------------------------
# Update the Ground-State input template 
#---------------------------------------------------------
&alter_input(\%var, 'gs_template');
#---------------------------------------------------------

foreach my $ncount ( $var{config_start} .. $var{config_stop} ){
   
   #Create the Directories
   my $cur_dir = 'Oxygen_'.$ncount;
   
   #----------------------------------------------
   #Check if the files exist, clean or create
   #----------------------------------------------
   if ( -d $cur_dir ){ 
      unlink glob "$cur_dir/*" or warn " ERROR: Cannot delete contents of Directory ($!)";
      unlink glob "$cur_dir/$var{gs_outdir}/*" 
   }
   else {
      mkdir $cur_dir, 0755 or die " ERROR: Cannot Create Directory ($!)";
      mkdir $cur_dir.'/'.$var{gs_outdir}, 0755 or die " ERROR: Cannot Create Directory ($!)";
   }
   #----------------------------------------------
   
   #----------------------------------------------
   # Create the init_atomic_pos.dat file that will 
   # have  all atoms with their atomic symbol  
   # (Will depend on the current excited Oxygen)
   # This will me useful later
   #----------------------------------------------
   my $atomic_pos_file = $cur_dir.'/init_atomic_pos.dat';
   open my $atomic_pos_fh, '>', $atomic_pos_file or die "ERROR: Cannot Open File ($!)";
   select $atomic_pos_fh;

   #Print the OO Atom to be excited in the current Configuration
   print 'OO '.$atoms[$ncount - 1];

   #print the Rest of the Atoms
   my $Ocount = 0;
   while (my ($index, $value) = each @atoms){
      if ( $Ocount < $var{numO}) {
         if ( $index != ($ncount - 1) ) {
            print 'O  '.$value;
            $Ocount++;
         }
      }
      else {
            print 'H  '.$value;
      }
   }
   select STDIN;
   close ($atomic_pos_fh);
   #----------------------------------------------

   #----------------------------------------------
   # Copy/append the GS template with atomic positions
   #----------------------------------------------
   #Copy Groundstate Template (test portability) and open file
   copy $var{gs_template}, $cur_dir.'/gs.in' ;
   
   # Append the Groundstate input File
   system("cat $atomic_pos_file >> $cur_dir'/gs.in'");
   #----------------------------------------------

   #----------------------------------------------
   # Copy the input hash to the directory # for 
   # use by the second major script: create_chmd.pl
   #----------------------------------------------
   open my $input_fh, '>', $cur_dir.'/input-file.in' or die ' ERROR: Cannot Open input-file.in: $!';
   while (my ($key, $value) = each %var ){
      print {$input_fh} "$key  =  $value\n";
   }
   #----------------------------------------------

   #----------------------------------------------
   # Create PBS Submit Script 
   #----------------------------------------------
   &create_qsub($ncount, \%var,$cur_dir,$exe_home);
   #----------------------------------------------

}
