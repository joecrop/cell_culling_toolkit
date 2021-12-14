#!/bin/bash

VOLTAGE=0.3
for MONTE in {1..100}
do
	echo "########################################################################"
	echo "###################### Simulating: $SIM of 100 ##########################"
	echo "###################### Running at: $VOLTAGE Volts ###########################"
	echo "########################################################################"
	../scripts/simulate_monte.pl `echo $VOLTAGE` `echo $MONTE` > ../temp/output_`echo $SIM`.log
done
