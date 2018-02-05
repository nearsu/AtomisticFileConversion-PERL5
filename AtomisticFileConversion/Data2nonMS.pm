package AtomisticFileConversion::Data2nonMS;

use strict;
use warnings;
use Math::Trig;
use Scalar::Util qw(looks_like_number);
use AtomisticFileConversion::Util_ChemicalData qw(ConvertElementSymbol2Number);
use AtomisticFileConversion::Util_Math qw(convertVectors);
use AtomisticFileConversion::Util_System qw(folderFileNameSplit findMSBinDirectory directoryPathCleaner fileFinder);
use AtomisticFileConversion::Util_Trajectory qw(firstStepTrajectory);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(Data2MSI);

sub Data2MSI {

	my ($fhTemp, $data) = @_;
	my $fileInformation = fileFinder($fhTemp, {
		'fileMode' 			=> 'WRITE',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILENAME',		# -> Looking for input or output file if a file handle - Manditory
	});
	open(my $fh, '>', $$fileInformation{'folder'}.$$fileInformation{'fileName'}.'.msi') or die "Can't open file: $!";
	
	
	my $scalingFactor;
	if (defined $$data{'scalingFactor'}){
		$scalingFactor = $$data{'scalingFactor'};
		die "scaling factor not 1" unless ($scalingFactor == 1);
	} else {
		$scalingFactor = 1;
	}
	looks_like_number($scalingFactor) || die "scaling factor is not numeric: $scalingFactor";
	
	# Get atomic coordinate type...
	if (defined $$data{'positionMethod'}){
		my $positionType = $$data{'positionMethod'};
		die "Coordinates not of type 'Direct'\n" 
			unless ($positionType=~/[Dd]/);
	}
	
	
	my $name = $$data{'header'};
	my $unitCell = $$data{'vectors'};
		
	# Get atoms and counts...
	my @atoms      = @{$$data{'chemicals'}};
	my @atomCounts = @{$$data{'chemicalCounts'}};
	die "Different number of elements and element counts" if ($#atoms != $#atomCounts);
	
	my @atomKey;
	
	#printData \@atomCounts;
	
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
	
	# Note: There may still be velocities and the like remaining in the file...
	
	
	## Write output
	
	# Header
	print $fh "# MSI CERIUS2 DataModel File Version 4 0\n";
	print $fh "(1 Model\n";
	print $fh "  (A I PeriodicType 100)\n";
	
	#Create the crystal
	printf $fh "  (A D A3 (%s %s %s))\n", $$unitCell[0][0], $$unitCell[0][1], $$unitCell[0][2];
	printf $fh "  (A D B3 (%s %s %s))\n", $$unitCell[1][0], $$unitCell[1][1], $$unitCell[1][2];
	printf $fh "  (A D C3 (%s %s %s))\n", $$unitCell[2][0], $$unitCell[2][1], $$unitCell[2][2];

	# Write atoms to CS...
	foreach my $index (0..$#$atomicVectors){
		my $element = $atomKey[$index];
		my $vector = $$atomicVectors[$index];
		my $cartVector = convertVectors($unitCell, $vector);
		
		printf $fh "  (%s Atom\n", $index + 2; # Index starts from 2 in *.msi files!?
		printf $fh "    (A I Id %s)\n", $index + 1; 
		printf $fh "    (A C ACL \"%s %s\")\n", ConvertElementSymbol2Number($element), $element;
		printf $fh "    (A D XYZ (%s %s %s))\n", $$cartVector[0], $$cartVector[1], $$cartVector[2];
		printf $fh "  )\n";
	}
	
	printf $fh ")\n";

	return;
}


1;
