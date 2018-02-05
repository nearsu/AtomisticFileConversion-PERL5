package AtomisticFileConversion::Data2MS;
# Note: This library requires use of the Materials studio perl library 
# Note: Therefore it must be used within the Materials Studio program

use strict;
use warnings;
use Math::Trig;
use Scalar::Util qw(looks_like_number);
use AtomisticFileConversion::Util_ChemicalData qw(ConvertElementSymbol2Number);
use AtomisticFileConversion::Util_Math qw(convertVectors);
use AtomisticFileConversion::Util_System qw(folderFileNameSplit findMSBinDirectory directoryPathCleaner);
use AtomisticFileConversion::Util_Trajectory qw(firstStepTrajectory);
use MaterialsScript qw(:all);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(Data2XSD XSD2data);


sub Data2XSD {

	my ($docName, $data) = @_;
	
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
	#printf "Total Atom Count: %s\n", $totalAtoms; 
	
	# Get remaining position entries...
	my $atomicVectors = $$data{'positions'};
	
	# Note: There may still be velocities and the like remaining in the file...
	
	
	## Write output
	
	#Create the new file
	my $newFilename = $docName.".xsd";
	my $doc = Documents->New($newFilename);
	
	
	#Create the crystal
	Tools->CrystalBuilder->SetSpaceGroup("P1", "");
	Tools->CrystalBuilder->SetCellVectors(
		Point(X => $$unitCell[0][0], Y => $$unitCell[0][1], Z => $$unitCell[0][2]), 
		Point(X => $$unitCell[1][0], Y => $$unitCell[1][1], Z => $$unitCell[1][2]), 
		Point(X => $$unitCell[2][0], Y => $$unitCell[2][1], Z => $$unitCell[2][2])
										  );
	Tools->CrystalBuilder->Build($doc);

	
	# Write atoms to CS...
	foreach my $index (0..$#$atomicVectors){
		my $vector = $$atomicVectors[$index];
		my $element = $atomKey[$index];
		my $newAtom = $doc->CreateAtom(
			$element, 
			$doc->FromFractionalPosition(
				Point( X => $$vector[0], Y => $$vector[1], Z => $$vector[2])
			)
		);
	}
	
	return $doc;
	
}




sub XSD2data {
	my ($doc, $controlData) = @_;

	my @atoms = @{$doc->UnitCell->Atoms};
	@atoms = sort {$a->Name cmp $b->Name} @atoms;
	#@atoms = sort {$a->ElementSymbol cmp $b->ElementSymbol} @atoms;
	
	#Custom sort subroutine list
	foreach my $sortSubroutine (@{$$controlData{'sortSubroutines'}})
	{
		#my $sortSubroutine = (${$$controlData{'sortSubroutines'}}[0]);
		@atoms = sort $sortSubroutine @atoms;
	};
	
	my $header = { 'header' => $doc->Name };
	
	# Unit Cell
	my $lattice = $doc->SymmetryDefinition;
	my $vectors = [
		$doc->SymmetryDefinition->VectorA, 
		$doc->SymmetryDefinition->VectorB, 
		$doc->SymmetryDefinition->VectorC
	];
	my $unitCell = {
		'scalingFactor' => 1,
		'vectors' => [
			[$$vectors[0]->X, $$vectors[0]->Y, $$vectors[0]->Z],
			[$$vectors[1]->X, $$vectors[1]->Y, $$vectors[1]->Z],
			[$$vectors[2]->X, $$vectors[2]->Y, $$vectors[2]->Z]
		]
	};
	
	# Chemicals
	my @chemicals;
	push (@chemicals, $_->ElementSymbol) foreach (@atoms);
	my $chemicalList;
	my $chemicalCounts;
	
	{
		ELEMENT: foreach my $elementSymbol (@chemicals){
			if (
				(ref($chemicalList) ne 'ARRAY') || # Initialise arrays...
				($$chemicalList[-1] ne $elementSymbol) # New element...
			){ 
				# Add new element to lists...
				push @$chemicalList, $elementSymbol;
				push @$chemicalCounts, 1;
				next ELEMENT;
			} else {
				$$chemicalCounts[-1] += 1;
			}
		}
	}
	my $chemicals = {
		'chemicals' => $chemicalList,
		'chemicalCounts' => $chemicalCounts
	};

	
	# Positions -> Fractional
	my $positionsList;
	
	foreach my $atom (@atoms){
		push @$positionsList, [
			$atom->FractionalXYZ->X,
			$atom->FractionalXYZ->Y,
			$atom->FractionalXYZ->Z
		];
	}
	
	my $positions = {
		'positionMethod' => 'Direct',
		'positions' => $positionsList
	};

	return {
		%$header,     
		%$unitCell,   
		%$chemicals, 
		%$positions, 
	};	
	
}



1;
