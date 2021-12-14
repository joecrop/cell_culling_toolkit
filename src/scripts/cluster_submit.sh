#!/bin/csh

source ~joseph/.cshrc
echo this script pid is $$
echo Working directory is $LJRS_O_WORKDIR
echo LJRS_0_WORKDIR is $LJRS_O_WORKDIR
cd $LJRS_O_WORKDIR
echo Runing on host `hostname`
echo Time is `date`
echo Directory is `pwd`
echo This jobs runs on the following processors:
echo \$LJRS_NODEFILE=$LJRS_NODEFILE
echo `cat $LJRS_NODEFILE`
set NPROCS=`wc -l < $LJRS_NODEFILE`
echo This job has allocated $NPROCS nodes
sed 's/c/g/' $LJRS_NODEFILE > $$.machinefile

./simulate_monte.pl 0.5 0

rm -f $$.machinefile
