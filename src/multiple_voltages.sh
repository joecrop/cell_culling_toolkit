#!/bin/bash

for VOLTAGE in 0.2 0.25 0.3 0.35 0.4 0.45 0.5
do
	echo "########################################################################"
	echo "###################### Simulating: $SIM ###############################"
	echo "###################### Running at: $VOLTAGE Volts ###########################"
	echo "########################################################################"
	../scripts/simulate_monte.pl `echo $VOLTAGE` 0 > ../temp/output_`echo $VOLTAGE`.log
done
