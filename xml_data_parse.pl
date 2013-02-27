#! /usr/bin/perl
#----------------------------------------------------------------------------
# This Script will read the data inside XML tags in the QE data-file.xml
#  For STEP0 and STEPM
#
# INPUT: 1) XML File Pathname
#        2) Directory where the data is to go
#        3+) tag name(s) to parse
#
# OUPUT: 1+) In the specified directory, all parsed data (with opening and 
#              closing tags) for STEP0 and STEPM
#----------------------------------------------------------------------------

use warnings;
use strict;
use 5.012;

#Pathname of the XML File
my $datafile = shift @ARGV;
open my $fh, '<', $datafile or die " ERROR: Cannnot Open File ($!)";

#Find the Directory where the out put is to go
my $dir = shift @ARGV;
$dir =~ s/\/\z//;

#Tags to find in each main STEP tag
#Usually force taui stau svel ht
my @tag_list = @ARGV;
my @step_types = qw( STEP0 STEPM );

#----------------------------------------------
#Read the data-file.xml
#----------------------------------------------
while (defined(my $line = <$fh>)){

   #Loop through both the current tag and the previous Steps
   foreach my $step (@step_types){

      if ($line =~ /<$step>/){
         while ( $line !~ /<\/$step>/){

            #loop through the tag
            &tag_loop($line, $step, $dir, @tag_list);

            #Read the Next Line
            $line = <$fh>;
         }
      }

   }
}

############################################################################

sub tag_loop{

   my ($line, $step, $dir, @tag_list) = @_;

         foreach my $tag (@tag_list){
            if ( $line =~ /<$tag(>|\s.*>)/ ){

               #Open the correct File
               open my $file, '>', $dir.'/'.${tag}.'_'.$step.'.dat';

               #Print the opening tag and read the next one
               print {$file} $line;
               $line = <$fh>;

               #Test to make sure its not the closing tag read in the data
               while ($line !~  /\/$tag(>|\s.*>)/ ){
                  print {$file} $line;
                  $line = <$fh>;
               }

               #Prints the closing tag and close file
               print {$file} $line; 
               close ($file);

            }
         }
}
