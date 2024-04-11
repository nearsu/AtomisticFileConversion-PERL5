package AtomisticFileConversion::Util_Field;

use strict;
use warnings;
use Math::Trig;
use Storable qw/freeze/;
$Storable::canonical = 1;
use List::Util qw(sum);
use Scalar::Util qw(looks_like_number);

use AtomisticFileConversion::Util_Math qw(checkVectorIntegrity convertVectors vectAbs vectUnit dot rotationAboutDirection_EulerParameters rotationAboutDirection_CombineEulerParameters rotationAboutDirection_EulerRotation);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(fieldVoxels fieldSum fieldMultiply fields2vectField fieldGrad fieldVectorUnit fieldVectorDot fieldVectorRotateSAXIS fieldZero vectField2fields);



sub fieldVoxels {
	my ($fieldRef) = @_;
	my $fieldVoxels;
	foreach (0..2){
		push @$fieldVoxels, $#{$fieldRef};
		$fieldRef = $$fieldRef[0];
	}
	
	return $fieldVoxels;
}


sub fieldSum {
	my @fields = @_;	
	my $field = shift @fields;	
	my $fieldVoxels = fieldVoxels($field);
	
	foreach my $fieldSum (@fields){
		foreach my $i (0..$$fieldVoxels[0]){
		foreach my $j (0..$$fieldVoxels[1]){
		foreach my $k (0..$$fieldVoxels[2]){
			my $fieldValue = \$$field[$i][$j][$k];
			my $fieldSumValue = \$$fieldSum[$i][$j][$k];
			looks_like_number($$fieldValue) || 
				die "Field value not a number in fieldSum subroutine";
			looks_like_number($$fieldSumValue) || 
				die "Field value not a number in fieldSum subroutine";
			
			$$fieldValue += $$fieldSumValue;
		}}}
	}
	
	return $field;
}

sub fieldMultiply {
	my ($field, $constant) = @_;
	
	looks_like_number($constant) || 
		die "Field value not a number in fieldSum subroutine";
	
	my $fieldVoxels = fieldVoxels($field);
	
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		my $fieldValue = \$$field[$i][$j][$k];
		looks_like_number($$fieldValue) || 
			die "Field value not a number in fieldSum subroutine";
		
		$$fieldValue *= $constant;
	}}}

	return $field;
}

sub fieldZero {
	my ($field) = @_;
	
	my $fieldVoxels = fieldVoxels($field);
	
	my $newField;
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		$$newField[$i][$j][$k] = 0;
	}}}

	return $newField;
}

sub fields2vectField {
	# Take 3 regular fields and combine into a vector field...
	my ($field1, $field2, $field3) = @_;
	my $vectField;
	
	# Get/check field dimensions:
	my $fieldVoxels = fieldVoxels($field1);
	die "Field dimensions are not the same between fields 1 and 2" unless freeze($fieldVoxels) eq freeze(fieldVoxels($field2));
	die "Field dimensions are not the same between fields 1 and 3" unless freeze($fieldVoxels) eq freeze(fieldVoxels($field3));
	
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
	
		my $value = [
			$$field1[$i][$j][$k],
			$$field2[$i][$j][$k],
			$$field3[$i][$j][$k]
		];
		
		$$vectField[$i][$j][$k] = $value;
	}}}

	return $vectField;	
}



sub fieldVectorRotateSAXIS {
	my ($saxis, $fieldVector) = @_;
	my $fieldVoxels = fieldVoxels($fieldVector);
	
	# Make SAXIS a unit vector:
	$saxis = vectUnit($saxis);
	die "SAXIS is [0, 0, 0]" if freeze($saxis) eq freeze([0, 0, 0]);
	
	my $unit1 = [0, 0, 1];
	my $unit2 = [0, 1, 0];
	
	
	# Determine euler rotation parameters
	my $angle1 = atan2($$saxis[1], $$saxis[0]);
	my $angle2 = atan2(sqrt($$saxis[0]**2+$$saxis[1]**2), $$saxis[2]);
		
	my $euler1 = rotationAboutDirection_EulerParameters($unit1, $angle1);
	my $euler2 = rotationAboutDirection_EulerParameters($unit2, $angle2);
	my $euler = rotationAboutDirection_CombineEulerParameters($euler2, $euler1);
	
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		my $vector = $$fieldVector[$i][$j][$k];
		$vector = rotationAboutDirection_EulerRotation($vector, $euler);
		$$fieldVector[$i][$j][$k] = $vector;
	}}}

	return $fieldVector;
}

sub vectField2fields {
	# Take vector field and split into 3 regular fields...
	my ($vectField) = @_;
	my ($field1, $field2, $field3);
	
	# Get/check field dimensions:
	my $fieldVoxels = fieldVoxels($vectField);
	
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		$$field1[$i][$j][$k] = $$vectField[$i][$j][$k][0];
		$$field2[$i][$j][$k] = $$vectField[$i][$j][$k][1];
		$$field3[$i][$j][$k] = $$vectField[$i][$j][$k][2];
	}}}

	return ($field1, $field2, $field3);	
}


sub fieldGrad {
	my ($data) = @_;
	# Use centralised finite differences (n=2) to approximate gradient vector field...
	
	# Need unit cell vectors:
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

	my $unitCell = $$data{'vectors'};

	# Need field:
	my $field = $$data{'field'};
	my $fieldVoxels = fieldVoxels($field);
	
	my @fieldScaling;
	foreach my $index (0..2) {
		my $unitCellVector = $$unitCell[$index];
		
		# Note: '**2' added due to requirement for vector scaled with unit cell
		$fieldScaling[$index] = ((vectAbs($unitCellVector))**2)/$$fieldVoxels[$index];
	}

	my $grad = [[[]]];
	
	foreach my $i (0..$$fieldVoxels[0]){
		print "($i/$$fieldVoxels[0])\n" if (($i % 10) == 0);
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		foreach my $dim (0..2){

			my $valueUp   = $$field
				[($i+($dim==0)) % $$fieldVoxels[0]]
				[($j+($dim==1)) % $$fieldVoxels[1]]
				[($k+($dim==2)) % $$fieldVoxels[2]]
			;
			
			my $valueDown = $$field
				[($i-($dim==0)) % $$fieldVoxels[0]]
				[($j-($dim==1)) % $$fieldVoxels[1]]
				[($k-($dim==2)) % $$fieldVoxels[2]]
			;
			
			looks_like_number($valueUp)   || die "Field value not a number in fieldSum subroutine";
			looks_like_number($valueDown) || die "Field value not a number in fieldSum subroutine";
			
			$$grad[$i][$j][$k][$dim] = ($valueUp - $valueDown)/(2*$fieldScaling[$dim]);
		}

		## Normalise vector back to regular x-y-z space:
		my $vector = $$grad[$i][$j][$k];
		$vector = convertVectors($unitCell, $vector);
		$$grad[$i][$j][$k] = $vector;

	}}}

	return $grad;
}

sub fieldVectorUnit {
	my ($fieldVector) = @_;
	my $fieldVoxels = fieldVoxels($fieldVector);
	my $fieldVectorNormal = [[[]]];
	
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		my $vector = $$fieldVector[$i][$j][$k];
		$vector = vectUnit($vector);
		$$fieldVectorNormal[$i][$j][$k] = $vector;

	}}}

	return $fieldVectorNormal;
}

sub fieldVectorDot {
	my ($fieldVector1, $fieldVector2) = @_;
	my $fieldVoxels = fieldVoxels($fieldVector1);
	my $fieldVoxels2 = fieldVoxels($fieldVector2);
	
	die "Field dimensions are not the same between fields 1 and 2" unless freeze($fieldVoxels) eq freeze(fieldVoxels($fieldVector2));
	
	my $fieldVectorDot = [[[]]];
	
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		my $vector1 = $$fieldVector1[$i][$j][$k];
		my $vector2 = $$fieldVector2[$i][$j][$k];
		
		my $scalar = dot($vector1, $vector2);
		$$fieldVectorDot[$i][$j][$k] = $scalar;

	}}}

	return $fieldVectorDot;
}


1;
