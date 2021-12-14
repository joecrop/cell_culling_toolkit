#!/usr/bin/perl

$voltage = $ARGV[0]; #subthreshold voltage
$monte = $ARGV[1]; # monte carlo run
print "#####################################################\n";
print "# Running simulation with sub-threshold voltage of: $voltage\n";
print "#####################################################\n";


################################
# CHANGE THESE VARIABLES ONLY! #
################################

# spice netlist containing subcircuits of every cell
$cell_netlist = '/home/mqxiao/hummingbird/Sub_Thershold/CULLING/CULLING/LIBRARY/smic13g.cdl';

# synopsys .lib file containing every cell (the corner, TT, SF, etc. doesn't matter because we only extract logic functions, not timing info).
$library = '/home/mqxiao/hummingbird/Sub_Thershold/CULLING/CULLING/LIBRARY/slow_1v08c125.lib';

# typical library operation voltage to be checked against [V].
$voltage_typ = 1.08;

# process node identifier used to name simulation output files only.
$process = "monte_sim";

# error percent in driving voltage calculations (recomended 0.90).  i.e. 90% of supply measy the driving voltage test passes
$error_percent = 0.90;

# name of NAND2 cell in library used in subcircuit definition (see README file)
$nand2_name = "NAND2X1";

# This sub contains all of the lines that needed to be included at the top of any spice sim deck.
sub add_libraries {
	print SIMFILE ".lib '/home/mqxiao/hummingbird/Sub_Thershold/CULLING/CULLING/LIBRARY/ms013_io33_v2p5.lib' MOS_MC\n";
	print SIMFILE ".inc '$cell_netlist'\n"; #netlists for cell library
	print SIMFILE ".temp 125\n";
	print SIMFILE ".option mcbrief=1\n";
	print SIMFILE "\n";
}

# absolute path to directory where reports are stored (i.e. /nfs/data/reports/).
$reports_dir = '../reports/';
# absolute path to directory where temp files are stored (i.e. /nfs/data/temp/).
$temp_dir = '../temp/';
# absolute path to directory where logs are stored (i.e. /nfs/data/logs/).
$log_dir = '../logs/';

##########################################
# DONT CHANGE ANYTHING AFTER THIS POINT! #
##########################################

open (TPHLRESULTS, '>'.$reports_dir.'tphl_delay_'.$process.'_'.$voltage.'.txt');
print TPHLRESULTS "CELLNAME\tTPHL_TYP\tTPHL_SUB\tTPHL_DIFF\n";
open (TPLHRESULTS, '>'.$reports_dir.'tplh_delay_'.$process.'_'.$voltage.'.txt');
print TPLHRESULTS "CELLNAME\tTPLH_TYP\tTPLH_SUB\tTPLH_DIFF\n";
open (SUBRESULTS, '>'.$reports_dir.'subthreshold_'.$process.'_'.$voltage.'.txt');
print SUBRESULTS "CELLNAME\tOUTPUT\tEXPECTED\tACTUAL\tPASS\n";

##################
# Robert's Code! #
##################
SKIP:
%outputs = ();
@inputs = ();
$cell_name = "";
$found_cell = 0;
$output_func = 0;
open LIBRARY, $library or die $!;
OUT:
while (my $line =<LIBRARY>) {
	if ($line =~ m/^cell/ && !$found_cell){
		my @cname = split(/\(/,$line);
		my @cname2 = split(/\)/,$cname[1]);
		$cell_name = $cname2[0];
#		if($cell_name =~ m/TBUF/)
#		{
			$found_cell = 1;
#		}
#		else
#		{
#			$found_cell = 0;
#		}
	}
	elsif ($line =~ m/^ *pin/ && $found_cell){
		my @pin_name_tmp = split(/\(/,$line);
		my @pin_name_tmp2 = split(/\)/,$pin_name_tmp[1]);
		my $pin_name = $pin_name_tmp2[0];
		$have_output = 0;
		$tri_state = 0;
		while($line =<LIBRARY>)
		{
			if($line =~ m/^ *direction : input/){	
				push(@inputs, $pin_name);
			}
			elsif($line =~ m/^ *direction : output/){
				while($line =<LIBRARY>){
					if($line =~ m/^ *function/){
						$output_func = 1;
						my @ofun = split(/\"/, $line);
						my $ofunc = $ofun[1];
						$outputs{$pin_name} = $ofunc;
						$have_output = 1;
					}
					elsif ($line =~ m/^ *three_state/) {
						$tri_state = 1;
						my @tris = split(/\"/, $line);
						$tri_state_pin = $tris[1];
					}
					elsif ($line =~ m/^ *\}/) {
						if($have_output == 0)
						{
							$output_func = 0;
							$found_cell = 0;
							$tri_state = 0;
							%outputs = ();
							@inputs = ();
							$cell_name = "";
						}
						next OUT;
					}
				}
			}
			elsif ($line =~ m/^ *\}/) {
				last;
			}
		}
	}
	elsif ($line =~ m/^ *latch\(/){
		$output_func = 0;
		$tri_state = 0;
		$found_cell = 0;
		%outputs = ();
		@inputs = ();
		$cell_name = "";
	}
	elsif($line =~ m/^ *ff\(/){
		$output_func = 0;
		$tri_state = 0;
		$found_cell = 0;
		%outputs = ();
		@inputs = ();
		$cell_name = "";
	}
	elsif ($line =~ m/^\}/ && $found_cell) {
		if($output_func == 1 && @inputs > 0){
			foreach $key (sort keys %outputs){
				while ($outputs{$key} =~ m/\!/){
					$outputs{$key} =~ s/\!/\~/g;
				}

				while ($outputs{$key} =~ m/([A-Z0-9]+) \(/){
					$outputs{$key} =~ s/([A-Z0-9]+) \(/$1\ & \(/g;
				}

				while ($outputs{$key} =~ m/([A-Z0-9]+) \~/){
					$outputs{$key} =~ s/([A-Z0-9]+) \~/$1\ & \~/g;
				}

				while ($outputs{$key} =~ m/\) ([A-Z0-9]+)/){
					$outputs{$key} =~ s/\) ([A-Z0-9]+)/\)\ & $1/g;
				}

				while ($outputs{$key} =~ m/\) +\~/){
					$outputs{$key} =~ s/\) +\~/\)\ & ~/g;
				}

				while ($outputs{$key} =~ m/([A-Z0-9]+) ([A-Z0-9]+)/){
					$outputs{$key} =~ s/([A-Z0-9]+) ([A-Z0-9]+)/$1\ & $2/g;
				}

				while ($outputs{$key} =~ m/\) \(/){
					$outputs{$key} =~ s/\) \(/\) & \(/g;
				}
			}		
			print "Inputs: @inputs\n";
			foreach $key (sort keys %outputs){
				print "Output ( $key ): $outputs{$key}\n";
			}
		}


		##############################################
		# From here on out goes inside Roberts code! #
		##############################################

		print "\n###################################################\n";
		print "##  RUNNING TEST ON CELL:  $cell_name\n";
		print "###################################################\n";
		#%spice is the hash for Joe
		my %spice;

		my (@truth, $c1, $c2, $line, $logic, $v, $c, $cref);
		my $max = @inputs;                 # Max number of vars

		#@truth is an array that starts out with '0 1' at $truth[0]
		$truth[0] = '0 1';

		#generate truth table combinations for all inputs
		for (1..($max-1)) {
			($c1 = $truth[$_-1]) =~ s/(\d+)/0$1/g;
			($c2 = $truth[$_-1]) =~ s/(\d+)/1$1/g;
			$truth[$_] = "$c1 $c2";
		}
		#break truth table combo strings into arrays of combos by index
		for (0..($max-1)) {
			#@comb = $truth[$_] split on whitespace into an array
			my @comb = split(/ /, $truth[$_]);
			#$truth[$_] is 2d array containing @comb
			$truth[$_] = \@comb;
		}

		#iterate through outputs hash
		#new hash for input names | vars
		my %vars;
		$v = ''; $c = 0;
		my @invars;
		for my $key (keys %outputs) {
			chomp($line = $outputs{$key});
			@_ = $line =~ /(\w+)/g;
			foreach(@_){
				if($_ ne "NOT" && $_ ne "AND" && $_ ne "OR"){
					push(@invars, $_);
				}
			}

			# Sort and retrieve unique var names
			for (@invars) {          				
				if (!defined($vars{$_})) {      
					$vars{$v = $_} = $c++;
					#build input keys and add them to the hash
					my $in_key = 'in_'.$v; 
					%spice -> {$in_key} = 0;
				}
			}
		}

		my $run_count = 0;
		$cref = $truth[scalar(keys %vars) - 1];
		print "@$cref\n";
		for (@$cref) {
			my $values = $_;
			for my $key (keys %outputs) {
				#chomp first hash element
				chomp($line = $outputs{$key});
				@_ = $line =~ /(\w+)/g;
				# Replace var names with logic values and evaluate
				$logic = $line;
				$logic =~ s/(\w+)/"0b".substr($values, $vars{$1}, 1)/eg;
				#build output keys and push them onto the hash
				my $out_key = 'out_'.$key;
				my $eval_logic = eval($logic);
				#test to see if eval($logic) result was undef
				if($eval_logic eq undef){
					#if so, set $eval_logic to 0
					print "UNDIFINED LOGIC FOR: { $logic } assuming 0\n";
					$eval_logic = 0;
				}
				$eval_logic = unpack("B*", pack("N", $eval_logic));
				$eval_logic = substr($eval_logic, -1);
				%spice -> {$out_key} = $eval_logic;
				#populate input pins with values
				for my $v_key (keys %vars){
					%spice -> {('in_'.$v_key)} = substr($values, $vars{$v_key}, 1);
				}
				if($tri_state == 1)
				{
					$tri_pin = $tri_state_pin;
					$tri_pin =~ s/\!//g;
					if($tri_state_pin =~ m/\!/)
					{
						$spice{'in_'.$tri_pin} = 1;
					}
					else
					{
						$spice{'in_'.$tri_pin} = 0;
					}
				}
			}
			#spice is populated
			#this section will execute n^2 times where n = no./inputs

			#examine %spice
			if($run_count == 0)
			{
				foreach my $k(sort keys %spice){
					print "$k\t";
				}
				print "\n";
			}

			foreach my $k1(sort keys %spice){
				my $v1 = $spice{$k1};
				print "$v1\t";
			}
			$run_count++;

			#open sim_deck file for writing
			open (SIMFILE, ">".$temp_dir."cell_sim_$voltage");

			print SIMFILE "\n"; #spice file needs head and tail linebreak
			print SIMFILE ".param sup=$voltage\n"; #voltage parameter
			print SIMFILE ".param mc_global=1\n";
			print SIMFILE "VVDD VDD 0 'sup'\n";
			print SIMFILE "VVNW VNW 0 'sup'\n";
			print SIMFILE "VVPW VPW 0 0\n";
			print SIMFILE "VVSS VSS 0 0\n";
			print SIMFILE "\n";
			add_libraries();

			# go through all variable and check for inputs or outputs
			while ( my ($key, $value) = each(%spice) ) {
				@data = split(/_/, $key);
				if( $data[0] eq "in" ) #is input
				{
					if($value eq '1')
					{
						print SIMFILE "v".$data[1]."_in ".$data[1]."_in 0 pulse(0 'sup' 900p 200p 200p 1000n)\n";
						print SIMFILE "XNAND_".$data[1]."_1 ".$data[1]."_a VDD ".$data[1]."_in $nand2_name \n";
						print SIMFILE "XNAND_".$data[1]."_2 ".$data[1]." VDD ".$data[1]."_a $nand2_name \n";
					}
					else
					{
						print SIMFILE "v".$data[1]."_in ".$data[1]."_in 0 pulse('sup' 0 900p 200p 200p 1000n)\n";
						print SIMFILE "XNAND_".$data[1]."_1 ".$data[1]."_a VDD ".$data[1]."_in $nand2_name \n";
						print SIMFILE "XNAND_".$data[1]."_2 ".$data[1]." VDD ".$data[1]."_a $nand2_name \n";
					}
				}
				else #is output
				{
					# add .measure command for 'avgX' where X is the output pin name
					print SIMFILE ".MEAS TRAN avg".$data[1]." AVG V(".$data[1].") FROM=900ns  TO=1000ns\n";
					print SIMFILE "XNAND_".$data[1]."_3 ".$data[1]."_out VDD ".$data[1]." $nand2_name \n";
				}
			}

			@inouts = ();
			# grab subckt entry from standard cell netlists file
			open (CELLNET, "<$cell_netlist");
			while (my $line = <CELLNET>) 
			{
				if($line =~ m/\.SUBCKT ($cell_name) /i)
				{
					@inouts = split(/ /, $line);
				}
			}
			close(CELLNET);

			#alter the subckt entry and plave it in the sim deck with the right entries
			print SIMFILE "x1 ";
			for($i = 2; $i < @inouts; $i++)
			{
				if($i < @inouts)
				{
					$inouts[$i] =~ s/\n//g;
					print(SIMFILE $inouts[$i]." ");
				}
			}
			print SIMFILE $cell_name."\n";

			print SIMFILE ".options list node\n";
			print SIMFILE ".tran 100p 1000n sweep monte=list($monte)\n";
			print SIMFILE "\n";
			print SIMFILE ".end\n\n";

			my $hspice = "hspice ".$temp_dir."cell_sim_$voltage -o ".$temp_dir."cell_sim_$voltage.out 2>> ".$log_dir."spice_$voltage.log";
			$hspice = `$hspice`;

			open (SPICEMT0, "<".$temp_dir."cell_sim_$voltage.out.mt0") or print STDERR " cannot open .mt0 file: $!\n";
			$line_found = 0;
			while (my $line = <SPICEMT0>) 
			{
				if($line =~ m/avg/) #first decliration line
				{
					@names = split(/\s+/, $line);
					$line =~ s/ +//g;
					$line_found = 1;
					
				}
				elsif($line_found == 1 && !($line =~ m/alter/)) #values
				{
					@results = split(/\s+/, $line);
					$line_found = 2;
				}
			} 
			print "\n";
			for($i = 0; $i < @names; $i++)
			{
				if(($names[$i] =~ m/avg/i))
				{
					$names[$i] =~ s/ *avg//g;
					$names[$i] = uc($names[$i]);
					if($spice{"out_".$names[$i]} == 1)
					{
						if(expand($results[$i]) > $voltage*$error_percent)
						{
							$PASS = 1;
						}
						else
						{
							$PASS = 0;
						}
					}
					elsif($spice{"out_".$names[$i]} == 0)
					{
						if(expand($results[$i]) < $voltage*(1-$error_percent))
						{
							$PASS = 1;
						}
						else
						{
							$PASS = 0;
						}
					}
					else
					{
						print "!!!!!!!!!!!!! BAD DATA !!!!!!!!!!!! : $names[$i]\n";
					}
					if($PASS == 0)
					{
						print "FAILURE FOUND IN CELL ($cell_name) ON OUTPUT ($names[$i]):\n";
						print ">\tEXPECTED LOGIC ".$spice{"out_".$names[$i]}.", RECIEVED ".expand($results[$i])."\n\n";
					}
					else
					{
						print "out_$names[$i]: PASS\n";
					}
					print SUBRESULTS "$cell_name\t$names[$i]\t".$spice{"out_".$names[$i]}."\t".expand($results[$i])."\t$PASS\n";
				}
			}

			close (SPICEMT0);

			# generate rise and fall condiotions
			my %inputs_trans, %trans_low, %trans_high;
			foreach my $k(sort keys %spice){
				my @isitout = split(/_/, $k);
				if($isitout[0] eq "out" && $spice{$k} eq "1")
				{
					foreach my $k1(sort keys %spice)
					{
						my @isitin = split(/_/, $k1);
						if($isitin[0] eq "in")
						{
							$trans_high{$k}{$k1} = $spice{$k1};
						}
						elsif($k1 eq $k)
						{
							$trans_high{$k}{$k1} = $spice{$k1};
						}
					}
				}
				elsif($isitout[0] eq "out" && $spice{$k} eq "0")
				{
					foreach my $k1(sort keys %spice)
					{
						my @isitin = split(/_/, $k1);
						if($isitin[0] eq "in")
						{
							$trans_low{$k}{$k1} = $spice{$k1};
						}
						elsif($k1 eq $k)
						{
							$trans_low{$k}{$k1} = $spice{$k1};
						}
					}
				}
			}

		}

		##########################################
		# Printing transition generating values! #
		##########################################
		print "trans_high!\n";
		foreach my $k(keys %trans_high){
			print $k." =>\n";
			$dref = $trans_high{$k};
			foreach my $k1 (keys %$dref){
				print "$k1 : $trans_high{$k}{$k1}\t";
			}
			print "\n";
		}
		print "trans_high!\n\n";

		print "trans_low!\n";
		foreach my $k(keys %trans_low){
			print $k." =>\n";
			$dref = $trans_low{$k};
			foreach my $k1 (keys %$dref){
				print "$k1 : $trans_low{$k}{$k1}\t";
			}
			print "\n";
		}
		print "trans_low!\n\n";

		################################################
		# test for rising edge and falling edge cases ##
		################################################

		# go through all variable and check for inputs or outputs
		foreach my $k(keys %trans_high)
		{
			#open sim_deck file for writing
			open (SIMFILE, ">".$temp_dir."cell_sim_$voltage");
			print SIMFILE "\n"; #spice file needs head and tail linebreak
			print SIMFILE ".param sup=$voltage_typ\n"; #voltage parameter
			print SIMFILE ".param mc_global=1\n";
			print SIMFILE "VVDD VDD 0 'sup'\n";
			print SIMFILE "VVPW VPW 0 0\n";
			print SIMFILE "VVNW VNW 0 'sup'\n";
			print SIMFILE "VVSS VSS 0 0\n";
			print SIMFILE "\n";

			add_libraries();

			print "TESTING tplh delay for: $k\n";
			my %in_change;
			$dref = $trans_high{$k};
			foreach my $key (sort( keys %$dref)) 
			{
				@data = split(/_/, $key);
				if( $data[0] eq "in" ) #is input
				{
					if($trans_high{$k}{$key} eq '1')
					{
						if($trans_low{$k}{$key} eq '1')
						{
							print SIMFILE "v".$data[1]." ".$data[1]." 0 pulse('sup' 'sup' 900p 200p 200p 1000n)\n";
						}
						else
						{
							$in_change{$key} = "0to1";
							print SIMFILE "v".$data[1]." ".$data[1]."_in 0 pulse(0 'sup' 900p 200p 200p 1000n)\n";
							print SIMFILE "XNAND_".$data[1]."_1 ".$data[1]."_a VDD ".$data[1]."_in $nand2_name \n";
							print SIMFILE "XNAND_".$data[1]."_2 ".$data[1]." VDD ".$data[1]."_a $nand2_name \n";
						}
					}
					else
					{
						if($trans_low{$k}{$key} eq '1')
						{
							$in_change{$key} = "1to0";
							print SIMFILE "v".$data[1]." ".$data[1]."_in 0 pulse('sup' 0 900p 200p 200p 1000n)\n";
							print SIMFILE "XNAND_".$data[1]."_1 ".$data[1]."_a VDD ".$data[1]."_in $nand2_name \n";
							print SIMFILE "XNAND_".$data[1]."_2 ".$data[1]." VDD ".$data[1]."_a $nand2_name \n";
						}
						else
						{
							print SIMFILE "v".$data[1]." ".$data[1]." 0 pulse(0 0 900p 200p 200p 1000n)\n";
						}
					}
				}
				else #is output
				{
					# add measure statement for tplh
					while ( my ($k2, $val2) = each(%in_change) )
					{
						print "input to change: $k2 => $val2\n";
						if($in_change{$k2} eq "0to1")
						{
							@in_name = split(/_/, $k2);
							@out_name = split(/_/, $key);
							print SIMFILE ".measure tran tplh TRIG v($in_name[1]) val='sup/2' rise=1 TARG v($out_name[1]) val='sup/2' rise=1\n";
							print SIMFILE "XNAND_".$out_name[1]."_3 ".$out_name[1]."_out VDD ".$out_name[1]." $nand2_name \n";
							last;
						}
						else
						{
							@in_name = split(/_/, $k2);
							@out_name = split(/_/, $key);
							print SIMFILE ".measure tran tplh TRIG v($in_name[1]) val='sup/2' fall=1 TARG v($out_name[1]) val='sup/2' rise=1\n";
							print SIMFILE "XNAND_".$out_name[1]."_3 ".$out_name[1]."_out VDD ".$out_name[1]." $nand2_name \n";
							last;
						}
					}
				}
			}

			@inouts = ();
			# grab subckt entry from standard cell netlists file
			open (CELLNET, "<$cell_netlist");
			while (my $line = <CELLNET>) 
			{
				if($line =~ m/\.SUBCKT ($cell_name) /i)
				{
					@inouts = split(/ /, $line);
				}
			}
			close(CELLNET);

			#alter the subckt entry and plave it in the sim deck with the right entries
			print SIMFILE "x1 ";
			for($i = 2; $i < @inouts; $i++)
			{
				if($i < @inouts)
				{
					$inouts[$i] =~ s/\n//g;
					print(SIMFILE $inouts[$i]." ");
				}
			}
			print SIMFILE $cell_name."\n";
			print SIMFILE ".options list node\n";
			print SIMFILE ".tran 100p 1000n sweep monte=list($monte)\n";
			print SIMFILE ".alter\n";
			print SIMFILE ".param sup=$voltage\n";
			print SIMFILE "\n";
			print SIMFILE ".end\n\n";

			my $hspice = "hspice ".$temp_dir."cell_sim_$voltage -o ".$temp_dir."cell_sim_$voltage.out 2>> ".$log_dir."spice_$voltage.log";
			$hspice = `$hspice`;

			open (SPICEMT0, "<".$temp_dir."cell_sim_$voltage.out.mt0") or print STDERR " cannot open .mt0 file: $!\n";

			$line_found = 0;
			while (my $line = <SPICEMT0>) 
			{
				if($line =~ m/tplh/) #first decliration line
				{
					@names = split(/\s+/, $line);
					$line =~ s/ +//g;
					$line_found = 1;
				}
				elsif($line_found == 1) #values
				{
					@results = split(/\s+/, $line);
				}
			}
			for($i = 0; $i < @names; $i++)
			{
				if($names[$i] eq "tplh")
				{
					$delay_time = expand($results[$i]);
				}
			}
			close (SPICEMT0);

			open (SPICEMT1, "<".$temp_dir."cell_sim_$voltage.out.mt1") or print STDERR " cannot open .mt1 file: $!\n";
			$line_found = 0;
			while (my $line = <SPICEMT1>) 
			{
				if($line =~ m/tplh/) #first decliration line
				{
					@names = split(/\s+/, $line);
					$line =~ s/ +//g;
					$line_found = 1;
				}
				elsif($line_found == 1) #values
				{
					@results = split(/\s+/, $line);
				}
			}
			for($i = 0; $i < @names; $i++)
			{
				if($names[$i] eq "tplh")
				{
					print TPLHRESULTS "$cell_name\t$delay_time\t".expand($results[$i])."\t".(expand($results[$i])/$delay_time)."%\n";
				}
			}
		}

		foreach my $k(keys %trans_low)
		{
			#open sim_deck file for writing
			open (SIMFILE, ">".$temp_dir."cell_sim_$voltage");

			print SIMFILE "\n"; #spice file needs head and tail linebreak
			print SIMFILE ".param sup=$voltage_typ\n"; #voltage parameter
			print SIMFILE ".param mc_global=1\n";
			print SIMFILE "VVDD VDD 0 'sup'\n";
			print SIMFILE "VVPW VPW 0 0\n";
			print SIMFILE "VVNW VNW 0 'sup'\n";
			print SIMFILE "VVSS VSS 0 0\n";
			print SIMFILE "\n";

			add_libraries();

			print "TESTING tphl delay for: $k\n";
			my %in_change;
			$dref = $trans_low{$k};
			foreach my $key (sort( keys %$dref)) 
			{
				@data = split(/_/, $key);
				if( $data[0] eq "in" ) #is input
				{
					if($trans_low{$k}{$key} eq '1')
					{
						if($trans_high{$k}{$key} eq '1')
						{
							print SIMFILE "v".$data[1]." ".$data[1]." 0 pulse('sup' 'sup' 900p 200p 200p 1000n)\n";
						}
						else
						{
							$in_change{$key} = "0to1";
							print SIMFILE "v".$data[1]." ".$data[1]."_in 0 pulse(0 'sup' 900p 200p 200p 1000n)\n";
							print SIMFILE "XNAND_".$data[1]."_1 ".$data[1]."_a VDD ".$data[1]."_in $nand2_name \n";
							print SIMFILE "XNAND_".$data[1]."_2 ".$data[1]." VDD ".$data[1]."_a $nand2_name \n";
						}
					}
					else
					{
						if($trans_high{$k}{$key} eq '1')
						{
							$in_change{$key} = "1to0";
							print SIMFILE "v".$data[1]." ".$data[1]."_in 0 pulse('sup' 0 900p 200p 200p 1000n)\n";
							print SIMFILE "XNAND_".$data[1]."_1 ".$data[1]."_a VDD ".$data[1]."_in $nand2_name \n";
							print SIMFILE "XNAND_".$data[1]."_2 ".$data[1]." VDD ".$data[1]."_a $nand2_name \n";
						}
						else
						{
							print SIMFILE "v".$data[1]." ".$data[1]." 0 pulse(0 0 900p 200p 200p 1000n)\n";
						}
					}
				}
				else #is output
				{
					# add measure statement for tplh
					while ( my ($k2, $val2) = each(%in_change) )
					{
						print "input to change: $k2 => $val2\n";
						if($in_change{$k2} eq "0to1")
						{
							@in_name = split(/_/, $k2);
							@out_name = split(/_/, $key);
							print SIMFILE ".measure tran tphl TRIG v($in_name[1]) val='sup/2' rise=1 TARG v($out_name[1]) val='sup/2' fall=1\n";
							print SIMFILE "XNAND_".$out_name[1]."_3 ".$out_name[1]."_out VDD ".$out_name[1]." $nand2_name \n";
							last;
						}
						else
						{
							@in_name = split(/_/, $k2);
							@out_name = split(/_/, $key);
							print SIMFILE ".measure tran tphl TRIG v($in_name[1]) val='sup/2' fall=1 TARG v($out_name[1]) val='sup/2' fall=1\n";
							print SIMFILE "XNAND_".$out_name[1]."_3 ".$out_name[1]."_out VDD ".$out_name[1]." $nand2_name \n";
							last;
						}
					}
				}
			}

			@inouts = ();
			# grab subckt entry from standard cell netlists file
			open (CELLNET, "<$cell_netlist");
			while (my $line = <CELLNET>) 
			{
				if($line =~ m/\.SUBCKT ($cell_name) /i)
				{
					@inouts = split(/ /, $line);
				}
			}
			close(CELLNET);
			#alter the subckt entry and plave it in the sim deck with the right entries
			print SIMFILE "x1 ";
			for($i = 2; $i < @inouts; $i++)
			{
				if($i < @inouts)
				{
					$inouts[$i] =~ s/\n//g;
					print(SIMFILE $inouts[$i]." ");
				}
			}
			print SIMFILE $cell_name."\n";
			print SIMFILE ".options list node post\n";
			print SIMFILE ".tran 100p 1000n sweep monte=list($monte)\n";
			print SIMFILE ".alter\n";
			print SIMFILE ".param sup=$voltage\n";
			print SIMFILE "\n";
			print SIMFILE ".end\n\n";

			my $hspice = "hspice ".$temp_dir."cell_sim_$voltage -o ".$temp_dir."cell_sim_$voltage.out 2>> ".$log_dir."spice_$voltage.log";
			$hspice = `$hspice`;

			open (SPICEMT0, "<".$temp_dir."cell_sim_$voltage.out.mt0") or print STDERR " cannot open .mt0 file: $!\n";

			$line_found = 0;
			while (my $line = <SPICEMT0>) 
			{
				if($line =~ m/tphl/) #first decliration line
				{
					@names = split(/\s+/, $line);
					$line =~ s/ +//g;
					$line_found = 1;
				}
				elsif($line_found == 1) #values
				{
					@results = split(/\s+/, $line);
				}
			}
			for($i = 0; $i < @names; $i++)
			{
				if($names[$i] eq "tphl")
				{
					$delay_time = expand($results[$i]);
				}
			}
			close (SPICEMT0);

			open (SPICEMT1, "<".$temp_dir."cell_sim_$voltage.out.mt1") or print STDERR " cannot open .mt1 file: $!\n";
			$line_found = 0;
			while (my $line = <SPICEMT1>) 
			{
				if($line =~ m/tphl/) #first decliration line
				{
					@names = split(/\s+/, $line);
					$line =~ s/ +//g;
					$line_found = 1;
				}
				elsif($line_found == 1) #values
				{
					@results = split(/\s+/, $line);
				}
			}
			for($i = 0; $i < @names; $i++)
			{
				if($names[$i] eq "tphl")
				{
					print TPHLRESULTS "$cell_name\t$delay_time\t".expand($results[$i])."\t".(expand($results[$i])/$delay_time)."%\n";
				}
			}
		}

		foreach my $k (sort( keys %trans_high)) {
			$dref = $trans_high{$k};
			foreach my $key (sort( keys %$dref)) {
				delete %$dref->{$key};
			}
			delete $trans_high{$k};
		}

		foreach my $k (sort( keys %trans_low)) {
			$dref = $trans_low{$k};
			foreach my $key (sort( keys %$dref)) {
				delete %$dref->{$key};
			}
			delete $trans_low{$k};
		}
		$output_func = 0;
		$found_cell = 0;
		%outputs = ();
		@inputs = ();
		$cell_name = "";
	}
}

close (LIBRARY);
close (TPLHRESULTS);
close (TPHLRESULTS);
close (SUBRESULTS);

# converts from sci. notation
sub expand {
       my $n = shift;
       return $n unless $n =~ /^(.*)e([-+]?)(.*)$/;
       my ($num, $sign, $exp) = ($1, $2, $3);
       my $sig = $sign eq '-' ? "." . ($exp - 1 + length $num) : '';
       return sprintf "%${sig}f", $n;
}

