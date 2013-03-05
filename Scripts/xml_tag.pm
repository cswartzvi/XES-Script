#! /usr/bin/perl
#----------------------------------------------------------------------------
# This Subroutine will read the data INSIDE XML tags and return it as an arrya
#
# INPUT: 1) XML File Pathname
#        2) tag name
#
# OUPUT: 1) return the values in between the tags as an array
#----------------------------------------------------------------------------

use warnings;
use strict;

sub xml_tag{
   
   #Input
   #  1) $xml_file = XML File to axtract data from
   #  2) $tag = name
   my ($xml_file, $tag) = @_;

   open my $fh, '<', $xml_file
      or die " ERROR: Cannot Open $xml_file: $!";

   #return array
   my @vals;

   #Count for two values
   my $ncount;
   while (defined(my $line = <$fh>)){
      chomp($line);
      
      #if tag is found
      if ($line =~ /<$tag.*>/){

         #Get the next line
         chomp($line = <$fh>);

         while ($line !~ /<\/$tag>/){

            push @vals, $line;

            #get the next line
            chomp($line = <$fh>);
   
         }
      }
   }
      
   close($fh);

   return @vals;
}
1;
