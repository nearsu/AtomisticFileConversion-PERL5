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
	my ($fh) = @_;
	my $fileInformation = fileFinder($fh, {
		'fileMode' 			=> 'READ',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=>	'CHGCAR',		# -> Default file name - Optional
	});
	$fh = $$fileInformation{'fileHandle'};
	
	my $cs = CAR2data($fh);
	return undef if (!defined $cs); 
	
	Line ($fh); # Blank line...
	
	
	# Check to see if at end of file or the header is repeated -> CHG file new frame marker
	# This indicates whether or not to load more charge densities...
	# Repeat 4 times total for maximum number of charge densities possible
	
	my $fields = {};
	FIELD: foreach my $index ('',1..3){
		# Read next line, test it and then rewind file handle...
		my $currentFhPosition = tell ($fh);
		die 'tell call error on file handle: $!' if ($currentFhPosition == -1);
		my $header = Header($fh);
		seek ($fh, $currentFhPosition, 0) || die 'seek function error on file handle: $!';
		
		if (
				(defined $header) &&
				($$header{'header'} ne $$cs{'header'})
		){
			my $fieldData = Field($fh);
			$$fields{"field$index"} = $$fieldData{'field'};
		} else {
			last FIELD;
		}
	}
	
	return {
		%$cs,
		%$fields,
	};
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
	};
	
	#printData $fieldSum;
	my $fieldAve = fieldMultiply ($fieldSum, (1/$count));
	#printData "FieldSumAve", $fieldAve ;
	return ($fieldAve, $trajectory, $count);
	

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
	
	my $fileInformation = fileFinder($folder, {
		'fileMode' 			=> 'READ',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=> 'OUTCAR',		# -> Default file name - Optional
	});	
	my $fh = $$fileInformation{'fileHandle'};
	
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


1;
