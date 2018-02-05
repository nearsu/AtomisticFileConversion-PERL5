package AtomisticFileConversion::Util_Math;

use strict;
use warnings;
use Math::Trig;
use Math::Trig ':pi';
use Scalar::Util qw(looks_like_number);
use Math::MatrixReal;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(vectors2angles scaleVectors convertVectors checkVectorIntegrity dot cross scalMult vectAdd vectSub vectAbs lengthToPlane vectUnit rotationAboutDirection checkEulerParameterIntegrity rotationAboutDirection_EulerParameters rotationAboutDirection_CombineEulerParameters rotationAboutDirection_EulerRotation);

sub convertVectors {
	my ($unitCellVectors, $vector) = @_;
	
	my $vectorMatrix = Math::MatrixReal->new_from_cols([$vector]);
	my $unitCellVectorsMatrix = Math::MatrixReal->new_from_cols($unitCellVectors);
	#my $unitCellVectorsMatrix = Math::MatrixReal->new_from_rows($unitCellVectors);
	
	my $outputVector = $unitCellVectorsMatrix*$vectorMatrix;
	
	return [$outputVector->element(1, 1), $outputVector->element(2, 1), $outputVector->element(3, 1)];
	
}



sub scaleVectors {
	my ($vectors, $scalingFactor) = @_;
	
	my $outVectors;
	foreach my $vector (@$vectors){
		my $tempVector;
		foreach my $value (@$vector){
			push @$tempVector, ($value * $scalingFactor);
		}
		push @$outVectors, $tempVector;
	}
	
	return $outVectors;
}

sub vectors2angles {
	my ($vectorsPerl) = @_;
	
	# Convert to 'column vectors'
	my $vectors;
	foreach my $vector (@$vectorsPerl){
		push @$vectors, Math::MatrixReal->new_from_cols([$vector]);
	}
	
	my $lengths;
	push @$lengths, $_->length() foreach (@$vectors);
	
	my $angles;
	foreach my $index(
		[1, 2], 
		[0, 2], 
		[0, 1], 
	){
		push @$angles, angle($$vectors[$$index[0]], $$vectors[$$index[1]]);
	}
	
	return {
		'lengths' => $lengths,
		'angles' => $angles,
	};
}


sub angle{
	# Angle between two vectors
	my $vectors = \@_;
	
	my $length;
	push @$length, $_->length() foreach (@$vectors);
	
	foreach my $length (@$length){
		die "length is zero or negative for vector\n" if ($length <= 0);
	}
	
	# Math: theta = acos ((A.B)/(|A|*|B|))
	my $angle = (~$$vectors[0] * $$vectors[1]);
	$angle = $angle->element(1,1);
	$angle /= ($$length[0]*$$length[1]);
	$angle = acos ($angle);
	
	# Degrees...
	$angle *= 180/pi;
	
	#print $angle;
	return $angle;
}


#### New functions, may not be compatible with old functions
#### Should probably all be handled by a much better library

sub checkVectorIntegrity {
	my @vectors = @_;
	
	foreach (@vectors) {
		my $vectorRef = $_;
		
		my @vector = @$vectorRef;
		
		# Check that there are three elements per input vector
		die ("More or less than three elements in vector, ") unless (($#vector + 1) == 3);
		
		# Check that all elements are numbers
		foreach (@vector){
			die "Element is non-numeric" unless (looks_like_number($_));
		}
	}
}



sub dot {
	# Input: This function takes two referenced arrays of length 3 and performs the 'dot-product' operation for 3-dimensions
	my ($a, $b) = @_;
	checkVectorIntegrity (@_);
	
	return (
		$$a[0]*$$b[0] +
		$$a[1]*$$b[1] +
		$$a[2]*$$b[2]
	);
	
}


sub cross {
	# Input: This function takes two referenced arrays of length 3 and performs the 'cross-product' operation for 3-dimensions
	my ($a, $b) = @_;
	checkVectorIntegrity (@_);
	
	return ([
		  $$a[1]*$$b[2] - $$a[2]*$$b[1]	 , 
		-($$a[0]*$$b[2] - $$a[2]*$$b[0]) , 
		  $$a[0]*$$b[1] - $$a[1]*$$b[0]
	]);
	
}

sub scalMult {
	# Input: Vector, scalar
	my ($a, $b) = @_;
	checkVectorIntegrity ($a);
	die "Element is non-numeric" unless (looks_like_number($b));
	
	return ([
		$$a[0]*$b,
		$$a[1]*$b,
		$$a[2]*$b,
	]);
}



sub vectAdd {
	# Input: Vector, vector
	my ($a, $b) = @_;
	checkVectorIntegrity (@_);
	
	return ([
		$$a[0] + $$b[0], 
		$$a[1] + $$b[1], 
		$$a[2] + $$b[2]
	]);
	
}

sub vectSub {
	# Input: Vector, vector
	my ($a, $b) = @_;
	checkVectorIntegrity (@_);
	
	return (vectAdd ($a, scalMult($b, -1)));
}

sub vectAbs {
	my ($a) = @_;
	checkVectorIntegrity (@_);
	
	return (sqrt(dot($a, $a)));
}

sub vectUnit {
	my ($a) = @_;
	checkVectorIntegrity (@_);
	
	my $scalingFactor = vectAbs($a);
	if ($scalingFactor == 0){
		warn "Length of vector is zero in conversion to unit vector\n";
		return [0, 0, 0];
	}
	#die "Length of vector is zero in conversion to unit vector" if $scalingFactor == 0;
	
	return (scalMult($a, (1/$scalingFactor)));
}

sub lengthToPlane {
	#http://mathworld.wolfram.com/Point-PlaneDistance.html
	#Length to a plane...
	# D_i=n^^*(x_0-x_i), 
	# where...
	# n^^=((x_2-x_1)x(x_3-x_1))/(|(x_2-x_1)x(x_3-x_1)|). 
	
	#Input: Point, plane vectors a, b, c.
	# All input scalars are referenced arrays of length 3 in cartesian space, eg, [x, y, z]
	
	
	#my ($a, $b, $c, @points) = @_;
	my ($plane, @points) = @_;
	my ($a, $b, $c) = @$plane;
	
	checkVectorIntegrity ($a, $b, $c);
	checkVectorIntegrity (@points);
	
	my $b_a = vectSub($b, $a);
	my $c_a = vectSub($c, $a);
	
	# Check that $a, $b, $c points do not have any duplicate vectors..
	foreach ([$a, $b],[$b, $c],[$c, $a]){
		my ($vector1, $vector2) = @$_;
		
		my $vector3 = vectSub($vector1, $vector2);
		my $test = 0;
		
		foreach (@$vector3){
			$test += abs($_);
		}
				
		die "Points are at the same position in space for plane definition\n" if $test == 0;
	}
	
	# Check that $a, $b, $c points are not in a line
	# abs((a-b dot a-c) / (|a-b||a-c|)) != 1
	die "Points are all in a line for plane definition\n" unless (1!= abs( (dot($b_a, $c_a)) / (vectAbs($b_a) * vectAbs($c_a))));
	
	# Calculate nHat
	# n^^=((x_2-x_1)x(x_3-x_1))/(|(x_2-x_1)x(x_3-x_1)|). 
	my $nHat = scalMult(cross ($b_a, $c_a), 
		  1/vectAbs(cross ($b_a, $c_a)));
	
	# Calculate Distances...
	my @distances;
	foreach (@points){
		my $point = $_;
		
		# D_i=n^^*(x_0-x_i), 
		push @distances, dot ($nHat, vectSub($point, $b));
	}
	
	return @distances;
}



#### End of vector functions... ####

# Perform a rotation about a given axis using the Euler–Rodrigues formula
# https://en.wikipedia.org/wiki/Euler%E2%80%93Rodrigues_formula


sub checkEulerParameterIntegrity {
	my @vectors = @_;
	
	# Probably more checks could be made here...
	
	foreach (@vectors) {
		my $vectorRef = $_;
		#printData $vectorRef;
		
		my @vector = @$vectorRef;
		
		# Check that there are three elements per input vector
		die ("More or less than four elements in euler parameters, ") unless (($#vector + 1) == 4);
		
		# Check that all elements are numbers
		foreach (@vector){
			die "Element is non-numeric" unless (looks_like_number($_));
		}
	}
}



sub rotationAboutDirection_EulerParameters {
	my ($rotationAxis, $angle) = @_;
	# Angle in radians;
	
	# Validata data...
	#$rotationAxis is vector
	#$rotationAxis is non-zero and make it a unit vector
	#$angle is scalar
	
	checkVectorIntegrity ($rotationAxis);
	$rotationAxis = vectUnit($rotationAxis);
	die "Angle is non-numeric" unless (looks_like_number($angle));
	
	
	# Create Euler Parameters for rotation...
	my $a = cos($angle/2);
	my $b = scalMult($rotationAxis, sin($angle/2));
	my $eulerParameter = [$a, @$b];
	
	return $eulerParameter;
	
}



sub rotationAboutDirection_CombineEulerParameters {
	my (@eulerParameters) = @_;
	
	# Validata data...
	#@eulerParameters are valid eulerParameters
	checkEulerParameterIntegrity($_) foreach @eulerParameters;

	my $output = [1, 0, 0, 0]; # No rotation as default

	foreach my $eulerParameter (@eulerParameters){
		# Combine eulerParameters
		#a = a_1 a_2 - b_1 b_2 - c_1 c_2 - d_1 d_2
		#b = a_1 b_2 + b_1 a_2 - c_1 d_2 + d_1 c_2
		#c = a_1 c_2 + c_1 a_2 - d_1 b_2 + b_1 d_2
		#d = a_1 d_2 + d_1 a_2 - b_1 c_2 + c_1 b_2

		#my $a = clone($output);
		my $a = [1, 0, 0, 0];
		my $b = $eulerParameter;
		
		
		$$output[0] = $$a[0]*$$b[0] - $$a[1]*$$b[1] - $$a[2]*$$b[2] - $$a[3]*$$b[3];
		$$output[1] = $$a[0]*$$b[1] + $$a[1]*$$b[0] - $$a[2]*$$b[3] + $$a[3]*$$b[2];
		$$output[2] = $$a[0]*$$b[2] + $$a[2]*$$b[0] - $$a[3]*$$b[1] + $$a[1]*$$b[3];
		$$output[3] = $$a[0]*$$b[3] + $$a[3]*$$b[0] - $$a[1]*$$b[2] + $$a[2]*$$b[1];
	}
	checkEulerParameterIntegrity($output);
	return $output;
	
}


sub rotationAboutDirection_EulerRotation {
	my ($vector, $eulerParameter) = @_;
	
	checkVectorIntegrity ($vector);
	checkEulerParameterIntegrity ($eulerParameter);
	
	my $a = $$eulerParameter[0];
	my $b = [
		$$eulerParameter[1],
		$$eulerParameter[2],
		$$eulerParameter[3]
	];
	
	# Perform rotation
	# x' = x + 2a(b*x) + 2(b*(b*x))
	
	my $output = 
		vectAdd(
			vectAdd(
				$vector, 
				scalMult(
					cross($b, $vector), 
					(2*$a)
				) 
			),
			scalMult(
				cross(
					$b, 
					cross(
						$b, 
						$vector
					)
				), 
				2
			)
		)
	;
	
	return $output;
}




sub rotationAboutDirection {
	
	my ($vector, $rotationAxis, $angle) = @_;
	# Angle in radians;
	
	# Validata data...
	#$vector is vector
	#$rotationAxis is vector
	#$angle is scalar
	
	checkVectorIntegrity ($vector, $rotationAxis);
	die "Angle is non-numeric" unless (looks_like_number($angle));
	
	
	# Create Euler Parameters for rotation...
	my $eulerParameter = rotationAboutDirection_EulerParameters($rotationAxis, $angle);
	
	# Perform rotation of vector
	my $outputVector = rotationAboutDirection_EulerRotation($vector, $eulerParameter);
	
	return $outputVector;
	
}


1;
