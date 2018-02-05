package AtomisticFileConversion::Util_Trajectory;

use strict;
use warnings;
use File::Spec;
use Scalar::Util qw(looks_like_number);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(is_integer_string initialiseSteps sliceTrajectory firstStepTrajectory processTrajectory processTrajectoryObjects);

sub is_integer_string { 
	# Taken from http://www.perlmonks.org/?node_id=614452 -> Camel book...
	# a valid integer is any amount of white space, followed
	# by an optional sign, followed by at least one digit,
	# followed by any amount of white space
	return $_[0] =~ /^\s*[\+\-]?\d+\s*$/;
}


sub initialiseSteps {
	my ($steps) = @_;
	
	my ($step, $end, $start);
	
	if (defined ($steps)){
		($step, $end, $start) = @$steps;
	}
	
	# Default values for stepping algorithm...
	$start = 0 unless defined ($start);
	$end = -1 unless defined ($end);
	$step = 1 unless defined ($step);
	
	die "Step not a number: $step\n"        unless looks_like_number($step);
	die "Step is zero or negative: $step\n" unless $step > 0;
	die "Step not ingeter: $step\n"         unless is_integer_string($step);
	
	die "Step not a number: $start\n"       unless looks_like_number($start);
	die "Start not ingeter: $start\n"       unless is_integer_string($start);
	die "Start less than zero: $start\n"    unless $start >= 0;
	
	die "Step not a number: $end\n"         unless looks_like_number($end);
	
	return [$step, $end, $start];
}



sub sliceTrajectory { # Given start, stop, step and index, return whether to skip step or not...
	my ($dataHash) = @_;
	my $index = $$dataHash{'StepValue'};
	my $steps = $$dataHash{'Steps'};
	$steps = initialiseSteps($steps);
	
	my ($step, $end, $start) = @$steps;
	
	# End of trajectory...
	return -1 if (
		($end != -1) &&
		($index > $end)
	);
	
	# Skip trajectories which will not have any input...
	return -1 if (
		($end != -1) &&
		($start > $end)
	);
	
	# Do nothing till the start point...
	return 0 if ($index < $start);
	
	# Select certain steps...
	return 1 if (($index - $start) % $step) == 0;
	
	# Else do nothing...
	return 0;

}


sub firstStepTrajectory {
	my ($dataHash) = @_;
	my $index = $$dataHash{'StepValue'};
	my $steps = $$dataHash{'Steps'};
	$steps = initialiseSteps($steps);
	my ($step, $end, $start) = @$steps;
	
	return 1 if $index == $start;
	return 0;
}





sub processTrajectory {
	# General step by step subroutine for processing trajectories...
	# In: Two references to subroutines and arguements which define the input and output trajectory actions, also steps data if available...
	# Called as...
	# my $trajectory = processTrajectory(\&inputTrj,$inputArgument,\&outputTRJ,$outputArgument);
	# my $trajectory = processTrajectory(\&inputTrj,$inputArgument,\&outputTRJ,$outputArgument,[$step, $end, $start]);
	
	# It may be cleaner if each set of trajectory instructions was an object with internally stored data...
	
	my ($subInputTrajectory, $argsInputTrajectory, $subOutputTrajectory, $argsOutputTrajectory, $steps) = @_;
	
	my $dataHashInput;
	my $dataHashOutput;
	
	$$dataHashInput{'Steps'} = initialiseSteps($steps);
	$$dataHashOutput{'Steps'} = $$dataHashInput{'Steps'};
	
	$$dataHashInput {'Args'}  = $argsInputTrajectory;
	$$dataHashOutput{'Args'} = $argsOutputTrajectory;
	$$dataHashInput {'Sub'}  = $subInputTrajectory;
	$$dataHashOutput{'Sub'} = $subOutputTrajectory;
	
	
	# Execute header...
	$$dataHashInput {'Header'} = $dataHashInput ->{'Sub'}->($dataHashInput , 'Header')->($dataHashInput );
	$$dataHashOutput{'Header'} = $dataHashOutput->{'Sub'}->($dataHashOutput, 'Header')->($dataHashOutput);
	
	#print Dumper($dataHash);
	
	# Execute Body...
	my $count = -1;
	while ( 
		my $data = do{
			$count++;
			$$dataHashInput {'StepValue'} = $count;
			$$dataHashOutput{'StepValue'} = $count;
			$dataHashInput ->{'Sub'}->($dataHashInput, 'Body')->($dataHashInput);
		}
	){
		my $sliceTrajectory = sliceTrajectory($dataHashInput);
		next if $sliceTrajectory == 0;   # Skip step...
		last if $sliceTrajectory == -1; # End of trajectory...
		#return 1 if $sliceTrajectory == 1;   # Process step...
		
		my $outputReturnValue = $dataHashOutput->{'Sub'}->($dataHashOutput, 'Body')->($dataHashOutput, $data);
		return $outputReturnValue if defined $outputReturnValue;
	}
	
	# Execute Footer...
	$$dataHashInput {'Footer'} = $dataHashInput ->{'Sub'}->($dataHashInput , 'Footer')->($dataHashInput );
	$$dataHashOutput{'Footer'} = $dataHashOutput->{'Sub'}->($dataHashOutput, 'Footer')->($dataHashOutput);
	
	return $$dataHashOutput{'Footer'};
}








sub processTrajectoryObjects {
	my ($hash) = @_;
	
	$$hash{'Steps'} = initialiseSteps($$hash{'Steps'});
	
	my @inputObjects;
	if (ref($$hash{'input'}) eq 'ARRAY'){
		@inputObjects = @{$$hash{'input'}};
	} else {
		@inputObjects = ($$hash{'input'});
	}
	
	# Execute Body...
	$$hash{'StepValue'} = 0;
	foreach my $inputObject (@inputObjects){
		for (
			;
			my $data = $inputObject->body;
			$$hash{'StepValue'}++
		){
			my $sliceTrajectory = sliceTrajectory($hash);
			#printf "slice: %s\n", $sliceTrajectory;
			next if $sliceTrajectory == 0;   # Skip step...
			last if $sliceTrajectory == -1; # End of trajectory...
			#return 1 if $sliceTrajectory == 1;   # Process step...
			
			my $stepsData = {
				'StepValue' => $$hash{'StepValue'},
				'Steps'     => $$hash{'Steps'},
			};
			
			printf "Step: %s\n", $$hash{'StepValue'}
				if (($$hash{'StepValue'}%100) == 0);
			
			my $outputReturnValue = $$hash{'output'}->body($data, $stepsData);
			return $outputReturnValue if defined $outputReturnValue;
		}
	}
	
	return $$hash{'output'}->DESTROY();
}




1;

