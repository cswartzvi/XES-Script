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
use FindBin qw($Bin);


sub read_variables{

   #for the appending of the templates
   #first time = 1, after that = 0
   my $append = shift @_;

   #Get the filename
   my ($input_file) = shift @_;
   open my $fh, '<', $input_file or die " ERROR: Cannot Open $input_file : $!";

   #Main Run-Time Variables
   my %var;
   %var = (
      config_start            => 1,                   #Starting Excited Oxygen
      config_stop             => '',                  #Ending Excited Oxygen
      procs                   => '',                  #Number of normal Processor (PW, CP, PWnscf, CPnscf)
      prefix                  => '',                  #Prefix for the QE input Files
      numO                    => '',                  #Number of Oxygens
      numH                    => '',                  #Number of Hydrogens
      nat                     => '',                  #Total Atoms (Oxygen + Hydrogen)
      val_bands               => '',                  #Number of Valence Bands (used in GS, CHMD, PW, and CP)
      con_bands               => '',                  #Number of Conduction Bands (used in PWnscf, CPnscf)
      tot_bands               => '',                  #Total Valence and Conduction bands
      celldm                  => '',                  #Lattice constant (From MD Simulation)
      pseudo_dir              => '',                  #Pseudopotential Directory
      template_dir            => '',                  #Directory for ALL Templates
      main_dir                => '',                  #Directory of the Original MD Simulation
      md_xml                  => '',                  #XMl File from the Original MD SImulation
      gs_template             => '',                  #Excited Oxygen GS Template
      gs_outdir               => 'Data-Files_GS',     #outdir in QE files (GS)
      chmd_template           => '',                  #Excited Oxygen CHMD Template
      chmd_outdir             => 'Data-Files_CHMD',   #outdir in QE files (CHMD)
      xes_steps               => undef,               #array reference -> which CHMD steps will perform XES calculations
      pw_template             => '',                  #PW template Calculation (1/5)
      pwnscf_template         => '',                  #PWnscf template Calculation (2/5)
      cpnscf_template         => '',                  #CPnscf template Calculation (3/5)
      cpnscf_print_template   => '',                  #CPnscf print-out template Calculation (4/5)
      gen_proj_template       => '',                  #Gen Projections template (5/5)
      pbe_outdir              => 'Data-Files_PBE',    #outdir for QE files (All GWs)
      submit_template         => '',                  #submit bash script (PBS ..)
      para_prefix             => '',                  #Command to execute parallel run (aprun, mpirun,...)
      para_flags              => '',                  #Parallel command Flags (-n or -np MUST be last)
      pw_qe                   => '',                  #Path to QE PW executable
      cp_qe                   => '',                  #Path to QE CP executable
      cp_mod_qe               => '',                  #Path to MODIFIFED QE CP executable (Was used in the cohsex) 
      gen_proj                => '',                  #Path to Gen projections
      gen_proj_run            => 0,                   #Flag to run the output of wavefunctions (default = off)
      gs_skip                 => 0,                   #True/false if the gs step has already finished
   );
   #------------------------------------------------------
   #Loop through the input file
   #------------------------------------------------------
   while (defined(my $line = <$fh>)){
      chomp($line);

      #Split on the equal sign
      if (my @temp = split /\s*=\s*/, $line) {

         #loop over the values of the hash
         while ( my ($key, $value) = each %var ) {
            if ($temp[0] eq $key){

               #remove any commas or spaces from the end of the line
               $temp[1] =~ s/(\s+|,)\z//;

               if ($key eq 'xes_steps'){
                  #create an arrya reference to the steps
                  $var{xes_steps} = [split ' ', $temp[1]]; 
               }
               else {
                  $var{$key} = $temp[1];
               }
            }
         }

      }

   }
   #------------------------------------------------------

   #------------------------------------------------------
   # Alter and add a few values 
   #------------------------------------------------------
   #Add templates Directory to all templates!
   #if $append = 0 (first time through)
   if ($append){
      while ( my($key, $value) = each %var){
         if ($key =~ /.*_template/){
            $var{$key} = $var{template_dir}.'/'.$var{$key};
         }
      }
      #sort the xes_steps
      @{$var{xes_steps}} = sort { $a <=> $b } @{$var{xes_steps}};
   }

   #Total Bands
   $var{tot_bands} = $var{val_bands} + $var{con_bands};
   #Total Atoms
   $var{nat} = $var{numO} + $var{numH};
   #------------------------------------------------------

   close($fh);
   return %var;
}

sub write_variables{

   #Main variables that have the name of the inputfile
   require "$Bin/mainvar.pl";
   our $input_file;

   #hash to be printed
   my $hash_ref = shift @_;
   my %var  = %{$hash_ref};

   #current directory
   my $cur_dir = shift @_;

   open my $input_fh, '>', "$cur_dir/$input_file" or die " ERROR: Cannot Open $input_file: $!";
   select $input_fh;

   while (my ($key, $value) = each %var ){

      if ($key eq 'xes_steps') {

         #make sure we are not abotu to print an undef array ref
         if (defined($value)){
            my $print_line = "@{$var{$key}}";
            printf("%-25s = %-25s \n", $key, $print_line );
         }

      }
      elsif ($key eq 'pbe_skip') {

         #make sure we are not abotu to print an undef array ref
         if (defined($value)){
            my $print_line = "@{$var{$key}}";
            printf("%-25s = %-25s \n", $key, $print_line );
         }

      }
      elsif (defined($value)) {
         printf("%-25s = %-25s \n", $key, $var{$key}); 
      }

   }
   select STDOUT;
   close ($input_fh);
}

sub stdout_variables{

   #hash to be printed
   my $hash_ref = shift @_;
   my %var  = %{$hash_ref};

   print "Input Variables:\n";
   foreach my $key ( sort keys %var ){

      if ($key eq 'xes_steps') {

         #make sure we are not about to print an undef array ref
         if ( defined($var{$key}) ){
            my $print_line = "@{$var{$key}}";
            printf(" %-25s = %-25s \n", $key, $print_line );
         }

      }
      else{
         printf(" %-25s = %-25s \n", $key, $var{$key}); 
      }

   }
   print "\n";
}
1;
