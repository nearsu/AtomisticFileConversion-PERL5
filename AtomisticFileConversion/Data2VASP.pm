package AtomisticFileConversion::Data2VASP;

use strict;
use warnings;
use Switch;
use Math::Trig;
use List::Util qw(sum);
use Scalar::Util qw(looks_like_number);

use AtomisticFileConversion::Util_Lines qw(:All);
use AtomisticFileConversion::Util_Field qw(fieldSum fieldMultiply);
use AtomisticFileConversion::Util_Trajectory qw(firstStepTrajectory);
use AtomisticFileConversion::Util_System qw(fileFinder);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(CAR2data Data2CAR CHG2data CHGMD2AverageField XDAT2sub CHG2sub DOSCAR2data OUTCAR2info CHG2traj Data2CAR_Header Data2CAR_Body);


sub CAR2data {
	my ($fh) = @_;
	my $fileInformation = fileFinder($fh, {
		'fileMode' 			=> 'READ',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=>	'POSCAR',		# -> Default file name - Optional
	});
	$fh = $$fileInformation{'fileHandle'};
	
	my $header    = Header ($fh);
	return undef if (!defined $header);
	
	my $unitCell  = UnitCell ($fh);
	my $chemicals = Chemicals ($fh);
	my $positions = Positions ($fh, $chemicals);
	
	return {
		%$header,     
		%$unitCell,   
		%$chemicals, 
		%$positions, 
	};	
	
}



sub Data2CAR {
	my ($fh, $data) = @_;
	my $fileInformation = fileFinder($fh, {
		'fileMode' 			=> 'WRITE',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=>	'POSCAR',		# -> Default file name - Optional
	});
	$fh = $$fileInformation{'fileHandle'};

	Data2CAR_Header($fh, $data);
	Data2CAR_Body($fh, $data);
}



sub Data2CAR_Header {
	my ($fh, $data) = @_;
	
	my $scalingFactor;
	if (!defined $$data{'scalingFactor'}){
		$scalingFactor = 1;
	} else {
		$scalingFactor = $$data{'scalingFactor'};
	}
	
	my $name;
	if (!defined $$data{'header'}){
		$name = 'CrystalStructure';
	} else {
		$name = $$data{'header'};
	}
	
	my $unitCell = $$data{'vectors'};
	die "No Unit cell vectors defined" unless defined $unitCell;
	
	# Get atoms and counts...
	my @atoms      = @{$$data{'chemicals'}};
	my @atomCounts = @{$$data{'chemicalCounts'}};
	die "Different number of elements and element counts" if ($#atoms != $#atomCounts);
	
	my @atomKey;
	
	foreach my $index (0..$#atoms){
		my $element = $atoms[$index];
		my $count = $atomCounts[$index];
		foreach (1..$count){
			push @atomKey, $element;
		}
	}
	
	# Count total number of atoms...
	my $totalAtoms = 0;
	$totalAtoms += $_ foreach @atomCounts;
	
	# Get remaining position entries...
	my $atomicVectors = $$data{'positions'};
	
	die "Different number of atoms in vector list and definitions" unless ($#{$atomicVectors} +1 ) == $totalAtoms;

	# Note: There may still be velocities and the like remaining in the file...	
	
	## Write output
	printf $fh "%s\n", $name;
	
	printf $fh "%s\n", $scalingFactor;
	
	foreach my $vector (@$unitCell){
		foreach my $value (@$vector){
			printf $fh "   %s", $value;
		}
		print $fh "\n";
	}
	
	printf $fh "   %s", $_ foreach (@atoms);
	print $fh "\n";
	
	printf $fh "   %s", $_ foreach (@atomCounts);
	print $fh "\n";
}


sub Data2CAR_Body {
	my ($fh, $data, $xdatcar) = @_;

	my $positionMethod;
	if (!defined $$data{'positionMethod'}){
		$positionMethod = 'Direct';
	} else {
		$positionMethod = $$data{'positionMethod'};
	}
	
	if (
		(defined($xdatcar))&&
		($xdatcar == 1)
	){
		my ($positionType) = $positionMethod =~ /^(.?)/;
		die 'position type not direct for XDATCAR file output' unless (($positionType eq 'd') || ($positionType eq 'D'));
		$positionMethod = '' # Make blank for XDATCAR file format
	}
	
	printf $fh "%s\n", $positionMethod; 

	# Get remaining position entries...
	my $atomicVectors = $$data{'positions'};
	
	foreach my $vector (@$atomicVectors){
		foreach my $value (@$vector){
			printf $fh " %s", $value;
		}
		print $fh "\n";
	}

}



sub CHG2data {
	my ($fh, $spin) = @_;
	my $fileInformation = fileFinder($fh, {
		'fileMode' 			=> 'READ',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=>	'CHGCAR',		# -> Default file name - Optional
	});
	$fh = $$fileInformation{'fileHandle'};
	
	my $cs = CAR2data($fh);
	return undef if (!defined $cs); 
	
	$spin = 1 unless defined $spin;
	
	Line ($fh); # Blank line...
	
	my $field = Field($fh);
	my $field2 = {};
	$field2 = Field($fh) if ($spin == 2);
	
	
	return {
		%$cs,
		%$field
	}
}

sub CHGMD2AverageField {
	my ($fh) = @_;
	
	my $fieldSum;
	my $trajectory;
	my $count = 0;
	while (my $data = CHG2data($fh)){
		$count++;
		print "$count\n";
		my $field = $$data{'field'};
		
		if (!defined($fieldSum)){
			$fieldSum = $field;
		} else {
			fieldSum ($fieldSum, $field);
		}
		
		delete $$data{'field'};
		push @$trajectory, $data;
		
		#last if $count > 2;
	}
	
	#printData $fieldSum;
	my $fieldAve = fieldMultiply ($fieldSum, (1/$count));
	#printData "FieldSumAve", $fieldAve ;
	return ($fieldAve, $trajectory, $count);
	

}


sub CHG2sub {
	my ($fh, $spin, $subroutine, $arguments) = @_;

	my $count = -1;
	while (my $data = CHG2data($fh, $spin)){
		$count++;

		# Send to subroutine
		my $result = &{$subroutine}($data, $count, $arguments);
		return $result if ($result != 0);
		
	}
	
	return 0;
}



sub DOSCAR2data {
	my ($fh) = @_;
	my $fileInformation = fileFinder($fh, {
		'fileMode' 			=> 'READ',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=> 'DOSCAR',		# -> Default file name - Optional
	});
	$fh = $$fileInformation{'fileHandle'};
	
	my $line1Array    = array ($fh);
	return undef unless (defined $line1Array);
	my $line2Array    = array ($fh);
	my $line3Array    = array ($fh);
	my $line4Array    = array ($fh);
	my $line5Array    = array ($fh);
	
	my $line6Array    = array ($fh);
	
	my $DOSLines = $$line6Array[2];
	return undef unless (looks_like_number($DOSLines));
	
	my @DOSArray;
	push @DOSArray, array ($fh) foreach (1..$DOSLines);
	
	return {
		'DOSArray' => \@DOSArray,
	};	
	
}



sub OUTCAR2info {
	# Read data from OUTCAR file...
	my ($folder, $field, $fieldPostion) = @_;
	
	# Convert file to folder and file name if necessary -> Make a utility for this...
	my $file = $folder.'/OUTCAR';
	open(my $fh, "<", $file) or die "Can't open file \"$file\" : $!";
	
	while (my $text = <$fh>){
		#my $result = $text=~/$field\s*\=\s*(.+)[\;$]/;
		my ($result) = $text=~/$field(.+)/;
		
		# Skip line if pattern not found...
		next unless ((defined $result) && ($result ne ''));

		# Else...
		{# Get values after '=' character
			my @results = split /=/, $result;
			$result = $results[1];
			return undef unless defined $result;
		}
		
		{# Get values before ';' character -> Often splits line in two
			my @results = split /;/, $result;
			$result = $results[0];
			return undef unless defined $result;
		}
		
		# Strip space from start and end of string...
		$result =~ s/\s+$//g;
		$result =~ s/^\s+//g;
		
		# Break string array and return specific values...
		if (defined $fieldPostion){		
			my @results = split /\s/, $result;
			$result = $results[$fieldPostion];
			return undef unless defined $result;
		}
		
		#print "(", $result, ")\n";
		close $fh or die "Cannot close file: $!\n";
		return $result;
		
	}
	close $fh or die "Cannot close file: $!\n";
	return undef;
}





sub CHG2traj {
	my ($arguements, $subroutineSection) = @_;
	
	my %subroutines = (
		'Header'	=> \&CHG2traj_Header,
		'Body'  	=> \&CHG2traj_Body,
		'Footer'	=> \&CHG2traj_Footer,
	);
	
	return $subroutines{$subroutineSection};
}

sub CHG2traj_Header {
	my ($dataHash) = @_; 
	my $args = $$dataHash{'Args'}; 
	my ($fileInFolder) = @$args; 
	
	my %data;
	
	#my $spin = 1; #### -> Load from OUTCAR file -> Grep and get first match for ISPIN!? What about NONCOLLINEAR!?
	## Also need time step or relaxation!? IBRION!? Total energy!? Forces!? Velocities!? Etc...
	
	my $spin = OUTCAR2field($fileInFolder, 'ISPIN', 0);
	die 'cannot find spin value from outcar file' unless defined $spin;
	printf "Spin: %s\n", $spin;
	$data{'spin'} = $spin;
	
	my $ibrion = OUTCAR2field($fileInFolder, 'IBRION', 0);
	die 'cannot find IBRION value from outcar file' unless defined $spin;
	printf "ibrion: %s\n", $ibrion;
	$data{'ibrion'} = $ibrion;
	
	if ($ibrion == 0){
		my $timeStep = 0;
		my $timeStepTemp = OUTCAR2field($fileInFolder, 'POTIM', 0);
		die 'cannot find timestep (POTIM) value from outcar file' unless defined $timeStepTemp;
		printf "POTIM: %s\n", $timeStepTemp;
		$timeStep = $timeStepTemp * 1e-15;
		$data{'timeStep'} = $timeStep;
	}
	
	my $fileInName = $fileInFolder . '/CHG'; #### Make more robust, split off CHG if necessary...
	print "In: $fileInName\n";
	die "No input file specified"  unless defined $fileInName;
	open(my $fh, "<", $fileInName) or die "Can't open file: $!";
	$data{'fh'} = $fh;
	
	return \%data;
}

sub CHG2traj_Body {
	my ($dataHash) = @_; 
	my $args = $$dataHash{'Args'}; 
	my $headerValues = $$dataHash{'Header'}; 
	my %timeHash;
	if (defined ($$headerValues{'timeStep'})){
		my $timeStep = $$headerValues{'timeStep'};
		%timeHash = ('timeStep' => $timeStep);
	}
	
	my $data = CHG2data($$headerValues{'fh'}, $$headerValues{'spin'});
	return {
		%$data,     
		%timeHash,
	};	


}

sub CHG2traj_Footer {
	return 1;
}


1;
