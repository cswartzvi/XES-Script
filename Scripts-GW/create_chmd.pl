#! /usr/bin/perl
#----------------------------------------------------------------------------
# Script to copy/modifiy the chmd.in template for a SINGLE Core-Hole MD
# Input File and (more importantly) Modify/Copy the GS data-file.xml so that 
# the CHMD can be started as a restart File
#
# IMPORTANT: This script is intended to be run from a PBS within the 
# directory created by the create_gs.pl script
# ---> IF NOT this will not work
#
#  INPUT 1) Number of current excited atom
#---------------------------------------------------------------------------

use warnings;
use strict;
use File::Copy qw(copy);
use Cwd 'cwd';
use FindBin qw($Bin);

#Main variables
require "$Bin/mainvar.pl";
our ($input_file, $init_atomic_pos_file, $atomic_pos_file, $chmd_in, $chmd_out);

require "$Bin/read_variables.pm";
require "$Bin/create_input.pm";

#Current Number of the Excited Atom
my $num = shift @ARGV;

#Root Output Directory -> Make CHMD outdir
my $cur_dir = cwd();

print"--------------------------------------------------------\n";
print" CHMD: cur_dir\n";
print"--------------------------------------------------------\n";

#---------------------------------------------------------
# Read in input-file.in namelist (Created by gs)
#---------------------------------------------------------
if (! -e "./$input_file"){
   die " ERROR Input File Not Specified : $!";
}

my %var = &read_variables(0, "./$input_file");

#reset the :
&stdout_variables(\%var);

#---------------------------------------------------------

#----------------------------------------------
#CHMD Outdir: Check, clean or create, copy 
#----------------------------------------------
if ( -d $var{chmd_outdir} ){ 
   print " $var{chmd_outdir} exists, checking previous CHMD...\n";

   #Check to see if the chmd.out file exists
   if (-f "$var{chmd_outdir}/$chmd_out" ){
      print " $var{chmd_outdir}/$chmd_out exists\n";

      #Check to be sure that the Job Was complete
      my $temp = `grep -q \"JOB DONE\" $var{chmd_outdir}/$chmd_out; echo \$?`;
      if ( $temp  == 0 ){
         print " Previous CHMD was completed,  updating $input_file to skip CHMD.\n";
         exit 1;
      }
      else {
         print " Previous CHMD was NOT completed\n";
         unlink glob "$var{chmd_outdir}/*" or warn " ERROR: Cannot delete contents of Directory:$!";
      }
   }
   else {
      print " No Previous $chmd_out file found, cleaning directory contents.\n";
      unlink glob "$var{chmd_outdir}/*" or warn " ERROR: Cannot delete contents of Directory:$!";
   }

}
else {
   print " Creating $var{chmd_outdir}.\n";
   mkdir $var{chmd_outdir}, 0755 or die " ERROR: Cannot Create Directory:$!";
}
print "\n";

#Copy the contents of the GS save directory to the CHMD save directory
system("cp -r $var{gs_outdir}/$var{prefix}_50.save $var{chmd_outdir}") ;
#----------------------------------------------

#----------------------------------------------
# Copy/append the CHMD template with atomic positions
#----------------------------------------------
&create_input($var{chmd_template}, "$var{chmd_outdir}/$chmd_in", 
   'prefix'         => $var{prefix},
   'pseudo_dir'     => $var{pseudo_dir},
   'outdir'         => './',
   'nat'            => $var{nat},
   'celldm(1)'      => $var{celldm},
   'nbnd'           => $var{val_bands});

# Append the CHMD input File with 
# atomic_init_pos.dat from create_gs.pl
if ( ! -e  $init_atomic_pos_file ){
   die " ERROR: $init_atomic_pos_file Not Found in $cur_dir";
}
system("cat $init_atomic_pos_file >> $var{chmd_outdir}/$chmd_in");
#----------------------------------------------

#----------------------------------------------
# Open all Files
#----------------------------------------------
#XML File from the previous GS Calculation
my $gs_xml =  "$var{gs_outdir}/$var{prefix}_50.save/data-file.xml";
open my $gs_xml_fh, '<', $gs_xml 
   or die " ERROR: Cannot Open $gs_xml ($!)"; 

#XML File for the CHMD
my $chmd_xml =  "$var{chmd_outdir}/$var{prefix}_50.save/data-file.xml";
open my $chmd_xml_fh, '>', $chmd_xml 
   or die " ERROR: Cannot Open $chmd_xml ($!)"; 

#------------------------------------
#select all OUPUT for the new chmd xml data-file.xml
select $chmd_xml_fh;
#------------------------------------

#Open all files that need to be changed in the current XML File
#Note: Certain tags will NOT need to changed. The stau0
#force and taui are examples. They are determined from the 
#Atomic positions, which were changed in create_gs.pl

#Open the svel STEP0 from the MD_Simulation
my @svel0 = &open_read("$var{main_dir}/svel_STEP0.dat");

#Open the stau STEPM from the MD_Simulation
my @stauM = &open_read("$var{main_dir}/stau_STEPM.dat"); 

#Open the svel STEPM from the MD_Simulation
my @svelM = &open_read("$var{main_dir}/svel_STEPM.dat");
#----------------------------------------------

#----------------------------------------------
#Loop through the Whole xml file, alter and rewrite
#----------------------------------------------
while (my $line = <$gs_xml_fh>){
 
         #Change the number of steps to ZERO?
         #TODO Check that this actually works (if not set to 10000 or something)
         $line =~ s/<STEP ITERATION=.*>/<STEP ITERATION="0"\/>/;

         #If we have found the Opening STEP0 tag, loop until closing
         if ($line =~ /<STEP0>/){
            while ( $line !~ /<\/STEP0>/){
               
               #Array: svel0
               $line = &write_tag($num, 'svel', \@svel0, $gs_xml_fh, $line); 
               
               #print and read the next line
               print $line;
               $line = <$gs_xml_fh>;

            }
            #Print the closing tag
            print $line;
         }
         #If we have found the Opening STEPM tag, loop until closing
         elsif ($line =~ /<STEPM>/){
           while ( $line !~ /<\/STEPM>/){
               
               #Array: tauM 
               $line = &write_tag($num, 'stau', \@stauM, $gs_xml_fh, $line); 
               
               #Array: svelM 
               $line = &write_tag($num, 'svel', \@svelM, $gs_xml_fh, $line); 

               #print and read the next line
               print $line;
               $line = <$gs_xml_fh>;

            }
            #Print the closing tag
            print $line;
         }
         #Print the reat of the file
         else{
            print $line;
         }

}
select STDOUT;
close($gs_xml_fh);
close($chmd_xml_fh);
#----------------------------------------------

##################################################################################
#  Subroutines
##################################################################################

#---------------------------------------------------------
#write the current tag array (From File) to current file handle
#---------------------------------------------------------
sub write_tag{

   #INPUT:
   #  1) Number for the excited Atom
   #  2) Current tag
   #  3) Current array reference
   #  4) Current File Handle
   #  5) Current Read-In Line

   #OUTPUT:
   #  1) Current Read-In Line

   my ($num, $tag, $array_ref, $fh, $line) = @_;
   my @array = @$array_ref;

   #Find the tag
   if ($line =~ /<$tag/){

      #Print the opening tag marker
      print $array[0];

      #print the Excited Atom first
      print $array[$num];

      foreach my $index (1 .. $#array){ 

         #Skip if the current atom IS the excited atom
         if ($index != $num){
            print $array[$index];
         }
         #Read the next line in the GS XMl
         $line = <$fh>;

      }
      #Read the next line after of the closing tag
      $line = <$fh>;
   }

   return $line;
}
#---------------------------------------------------------

#---------------------------------------------------------
# Open a File and read the FIle in to an array
#---------------------------------------------------------
sub open_read{

   my $filename= shift @_;

   open my $fh, '<', $filename or die " ERROR: Cannot Open $filename :$!";
   my @array = <$fh>;
   close ($fh);

   return @array;
#---------------------------------------------------------

}
