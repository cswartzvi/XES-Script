#PBS -q regular
#PBS -l mppwidth=64
#PBS -l walltime=00:59:00
#PBS -j eo
#PBS -V
#PBS -A m1542

cd $PBS_O_WORKDIR

find . -name "*.cmd.*" -exec rm {} \;

#aprun -n 64 /global/u1/x/xifanwu/nonortho2_April20_fast_Wannier/bin/pw.x < water64_scf.in > water64_coreholefroce.out
#aprun -n 64 /global/u1/x/xifanwu/nonortho2_April20_fast_Wannier/bin/pw.x < water64_scf_normal.in > water64_force.out
#aprun -n 64 /global/u1/x/xifanwu/espresso_hybridfunctional_2012/bin/cp.x  < cp.in > cp.out 
aprun -n 64 /global/u2/m/mohan/5_xifan/1_Xifan/1_espresso_hybridfunctional_2012/bin/cp.x < chmd.in > chmd.out
