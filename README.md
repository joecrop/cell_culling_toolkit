# Cell Culling Toolkit
Code for my publication: [Design automation methodology for improving the variability of synthesized digital circuits operating in the sub/near-threshold regime](https://ieeexplore.ieee.org/document/6008604)


## Prerequisites:
* Synopsys HSPICE or equivalent
* Perl
* Matlab
* a standard cell library with:
	* a synopsus .lib file
	* an hspice netlist for every cell
	* hspice models for the process

## RUNNING THE SCRIPT:
After editing the top section variables of "scripts/simulation_monte.pl" simply type:

$ simulate_monte.pl [sub_threshold voltage] [monte_carlo run parameter]

sub_threshold voltage: 		the voltage to be check against, for example: 0.4
monte_carlo_run_parameter: 	the monte carlo corner you want to test against, choose 0 for the mean case otherwise any number greater than 1 will give you a specific pseudo-random set of process variations.

For example:

$ simulate_monte.pl 0.4 0

## ANALYZING THE DATA:

Simply run the scripts/analyze_data.m file in Matlab
It will statistically determine which cells are bad.
Three variables are created:

good_cells: a list of all the cells that passed.
bad_cell: a list of all the cells that failed.
bad_cell_timing: a list of the timing of all the bad cells.


### If no valid data is generated:

Data is generated in the report directory.

If it is not there or all 0's first check the log files
The most common problem is with hspice model file inclusion

#### ANOTHER NOTE:

Because all inputs and outputs are connected to a NAND2 cell for driving the NAND2 cells is added to each simulation automatically. The format of the NAND2 cell's syntax is:

Xnand2 out in_a in_b VDD VSS VNW VPW Cell_name

where out, in_a, and in_b are dynamically generated based on what the connections need to be.
This is designed to test a tripplewell process so VNW and VPW are added as the n-well and p-well bulk supplies respectively.
If the order of output and inputs are different for the subcitcuits in your library you need to manually edit the following lines: 323,324,329,330,337,537,538,547,548,575,567,698,699,708,709,728,736.


