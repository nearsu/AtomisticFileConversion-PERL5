package AtomisticFileConversion::Util_DataTransform;

use strict;
use warnings;
use Storable qw(dclone);
use AtomisticFileConversion::Util_Math qw(rotationAboutDirection_EulerRotation);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(dataRotate);



sub dataRotate {
	# Rotate all vectors in data
	
	my ($dataInput, $eulerParameter) = @_;
	my $data = dclone($dataInput);
	
	# Data to adjust...
	# Positions, velocities, forces, unit cell parameters, anything else?
	# Note: Must be transformed in real space
	
	# Get atomic coordinate type...
	if (defined $$data{'positionMethod'}){
		my $positionType = $$data{'positionMethod'};
		die "Coordinates not of type 'Direct'\n" 
			unless ($positionType=~/[Dd]/);
	}
	
	my $unitCell = $$data{'vectors'};
	
	# Get remaining position entries...
	my $atomicVectors = $$data{'positions'};
	my $atomicVelocities = $$data{'velocities'};
	my $atomicForces = $$data{'forces'};
	
	# The following could be buggy due to lack of determination if co-ordinates are fractional(direct) or cartesian
	# However, the above lines should help...
	
	# Issue with whether coordinates are in fractional or cartesian for positions, velocities, forces, etc...
	
	foreach my $dataField ($unitCell){
		foreach my $vector (@$dataField){
			$vector = rotationAboutDirection_EulerRotation($vector, $eulerParameter);
		}
	}
	
	# Direct coordinates -> Don't have to do any rotation as projection is determined by unit cell parameters
	#foreach my $dataField ($atomicVectors, $atomicVelocities, $atomicForces){
	#	foreach my $vector (@$dataField){
	#		my $cartVector = convertVectors($unitCell, $vector);
	#		#$vector = rotationAboutDirection_EulerRotation($vector, $eulerParameter);
	#	}
	#}
	
	
	return $data;

}



# sub dataTranslate {
# Etc...


1;
