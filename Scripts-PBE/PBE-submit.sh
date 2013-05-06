#! /bin/bash
#PBS -q debug
#PBS -l mppwidth=128
#PBS -l walltime=00:30:00
#PBS -A m1628
#PBS -N XES-PBE-test

########################################################################################
#This script is TEMPORARY: It must be submitted in Oxygen_XX/PBE_caclulations/XXfs

#GW Number 
num=2

########################################################################################

cd $PBS_O_WORKDIR

#the atoms-file header
cat > atoms.dat <<EOF
   192 2 0
  23.51700000    0.00000000    0.00000000
   0.00000000   23.51700000    0.00000000
   0.00000000    0.00000000   23.51700000

EOF


#Copy the PWscf, PWnscf, and the CPnscf
cp ../../Data-Files_GW_${num}/gw_[134].in${num} .

#run the PW calculations
aprun -n 128 /global/homes/c/cswartz/Software/ffn2_tsvdw_master/bin/pw.x < gw_1.in${num}   > gw_1.out${num}
aprun -n 128 /global/homes/c/cswartz/Software/ffn2_tsvdw_master/bin/pw.x < gw_3.in${num}   > gw_3.out${num}

#copy the PW save directory into a cp save directory
cp -R water.save water_50.save

#Run the CPnscf
aprun -n 128 /global/homes/c/cswartz/Software/cohsex_lf/bin/cp.x         < gw_4.in${num}   > gw_4.out${num}

#Run the second CPnscf (will create the cp_wf.dat and print out the wavefunctions)
sed -e 's/\(nsteps\s\+=\s\+\).*/\1 1/g' gw_4.in${num} > gw_4-2.in${num}
echo "KSOUT \n256" >> gw_4-2.in${num} 
exit
aprun -n 128 /global/homes/c/cswartz/Software/cohsex_lf/bin/cp.x         < gw_4-2.in${num} > gw_4-2.out${num}

#run the print-xsf function
mkdir wavefunctions
mv KS_* WAN_* wavefunctions

tail -192 gw_1.in${num} >> atom.dat
sed -i -e 's/OO/16/g' -e 's/O/8/g' -e 's/H/1/g' atoms.dat

exit
aprun -n 64 -N 12 /global/homes/c/cswartz/Ext_Programs/Gen-Projections/print-xsf.x > xsf.out <<EOF
&projections
   spec_root   =  'wavefunctions/KS_',
   spec_ext    =  '.dat'
   nbsp        =  256
   print_xsf   =  .TRUE.
   atomfile    =  'atoms.dat'
   grid(1)     =  128,
   grid(2)     =  128,
   grid(3)     =  128,
   alat(1)     =  23.5170,
   alat(2)     =  23.5170,
   alat(3)     =  23.5170,
/
EOF
exit

#Run the XES script for PBE
cp ../../Data-Files_GW_${num}/atomic_pos.dat .
#This is a hack
cp ../../input-file.in . 
run_xes-PBE.pl $num /global/homes/c/cswartz/Scripts/XES_Script > xes.out
