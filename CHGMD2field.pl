#!/usr/bin/perl
# Note: The input to most reading and writing subroutines accept file names, folder names (assuming default file name), or file handles
# Note: Relative or absolute paths are both OK

use strict;
use warnings;
#use lib 'C:\My\Path\To\Libraries'; # Point to root folder containing the AtomisticFileConversion and Math folders
use FindBin qw($Bin);
use lib "$Bin";
use AtomisticFileConversion::Util_Trajectory qw(processTrajectoryObjects);

#### Input...

# CHG
my $chgIn  = 'C:\My\Path\To\CHG'; # File/folder containing the CHG file
use AtomisticFileConversion::Data2VASP::CHG2traj;


#### Process data...
use AtomisticFileConversion::Util_Trajectory::AverageField;

my ($data) = processTrajectoryObjects({

	# CHG 	
	'input'  => AtomisticFileConversion::Data2VASP::CHG2traj          ->new($chgIn),	 # CHG: VASP charge density and trajectory format (no forces, no velocities, no time step, etc...)
	
	# Output -> Process frames...
	'output' => AtomisticFileConversion::Util_Trajectory::AverageField->new(),		# Take field average of all frames and return
	
});
	
	
#### Output...
	
# VESTA *.grd
use AtomisticFileConversion::Data2Field qw(Data2Grd);
my $fileOut1 = 'C:\My\Path\To\Output\gridVesta.grd'; # File containing the VESTA *.grd file
Data2Grd($fileOut1, $data);

## Materials Studio *.grd
use AtomisticFileConversion::Data2Field qw(Data2GrdMS);
my $fileOut2 = 'C:\My\Path\To\Output\gridMS.grd'; # File containing the Materials Studio compatible *.grd file
Data2GrdMS($fileOut2, $data);

