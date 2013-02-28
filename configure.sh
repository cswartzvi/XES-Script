#!/bin/bash
#------------------------------------------------------------------------
#
# This Script will set up the requirements for the all of the scripts in
# the Scripts directory
# Should only be needed to run once
#
#------------------------------------------------------------------------


current_dir=$(pwd)
dir=${current_dir}/Scripts

#xes_init.pl
file=xes_init.pl
sed -i "s#$(grep -m 1 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/read_variables.pm\';#" $dir/${file} 
sed -i "s#$(grep -m 2 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/create_input.pm\';#"   $dir/${file}
sed -i "s#$(grep -m 3 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/create_qsub.pm\';#"    $dir/${file}
sed -i "s#$(grep -m 4 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/xml_data_parse.pm\';#" $dir/${file}
sed -i "s#$(grep -m 5 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/stau_to_tau.pm\';#"    $dir/${file}
sed -i "s#$(grep -m 1 "^my \$exe_home" Scripts/${file} | tail -1)#my \$exe_home = \'${current_dir}/Scripts\';#"     $dir/${file}

#create_chmd.pl
file=create_chmd.pl
sed -i "s#$(grep -m 1 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/read_variables.pm\';#" $dir/${file}
sed -i "s#$(grep -m 2 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/create_input.pm\';#"   $dir/${file}

#create_gw.pl
file=create_gw.pl
sed -i "s#$(grep -m 1 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/read_variables.pm\';#" $dir/${file}
sed -i "s#$(grep -m 2 "^require" Scripts/${file} | tail -1)#require \'${current_dir}/Scripts/create_input.pm\';#"   $dir/${file}