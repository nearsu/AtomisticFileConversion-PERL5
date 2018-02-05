#!/usr/bin/perl
# Note: The input to most reading and writing subroutines accept file names, folder names (assuming default file name), or file handles
# Note: Relative or absolute paths are both OK

use strict;
use warnings;
#use lib 'C:\My\Path\To\Libraries'; # Point to root folder containing the AtomisticFileConversion and Math folders
use FindBin qw($Bin);
use lib "$Bin";
use AtomisticFileConversion::Util_Trajectory qw(processTrajectoryObjects);
use AtomisticFileConversion::Util_Trajectory::Combine;
use AtomisticFileConversion::Util_Trajectory::FixedData;

######## Load libraries...

#### Input...

# XDATCAR 
my $xdatcarIn  = 'C:\My\Path\To\XDATCAR'; # File/folder containing the XDATCAR file
use AtomisticFileConversion::Data2VASP::XDAT2traj;
use AtomisticFileConversion::Data2VASP::XDAT2traj_5_2_12;
use AtomisticFileConversion::Data2VASP::XDAT2traj_5_3_5;


#### Output...

# XDATCAR 
my $xdatcarOut  = 'C:\My\Path\To\Output\XDATCAR'; # File/folder containing the XDATCAR file
use AtomisticFileConversion::Data2VASP::Traj2XDAT_5_2_12;
use AtomisticFileConversion::Data2VASP::Traj2XDAT_5_3_5;

# Materials Studio MDTR/trj
my $fileOut = 'C:\My\Path\To\Output\myTrajectory'; # Output file for trajectory
use AtomisticFileConversion::Data2MS::Traj2XTD_MDTR_2010;

## Materials Studio XTD
# Uncomment as requires materials studio
#my $trjName = 'myOutputTrajectory';
#use AtomisticFileConversion::Data2MS::Traj2XTD;



######## Process trajectory...

my ($result) = processTrajectoryObjects({

	#### Input...
	# Note: Multiple input files can be concatenated using an array of input objects
	# However, be aware that the code does not check that they are all compatible with each other

	# XDATCAR 	
	#'input'  => AtomisticFileConversion::Data2VASP::XDAT2traj        ->new($xdatcarIn), # XDATCAR: VASP trajectory format (version 5.2.12 or 5.3.5, automatic selection)
	#'input'  => AtomisticFileConversion::Data2VASP::XDAT2traj_5_3_5  ->new($xdatcarIn), # XDATCAR: VASP trajectory format (version 5.3.5) (no forces, no velocities, no time step, etc...)
	#'input'  => AtomisticFileConversion::Data2VASP::XDAT2traj_5_2_12 ->new($xdatcarIn), # XDATCAR: VASP trajectory format (version 5.2.12) (no unit cell parameter updates, no forces, no velocities, no time step, etc...)
	
	# XDATCAR with extra data such as time step...
	'input'  => AtomisticFileConversion::Util_Trajectory::Combine->new([
		AtomisticFileConversion::Data2VASP::XDAT2traj         ->new($xdatcarIn), 	# XDATCAR: VASP trajectory format (version 5.2.12 or 5.3.5, automatic selection)		
		#AtomisticFileConversion::Data2VASP::XDAT2traj_5_3_5  ->new($xdatcarIn), 	# XDATCAR: VASP trajectory format (version 5.3.5) (no forces, no velocities, no time step, etc...)
		#AtomisticFileConversion::Data2VASP::XDAT2traj_5_2_12 ->new($xdatcarIn), 	# XDATCAR: VASP trajectory format (version 5.2.12) (no unit cell parameter updates, no forces, no velocities, no time step, etc...)
		
		AtomisticFileConversion::Util_Trajectory::FixedData->new({'timeStep' => 5})		# XDATCAR: VASP trajectory format (version 5.2.12 or 5.3.5, automatic selection)		
	]) ,
	

	
	
	#### Output...

	# XDATCAR 
	'output' => AtomisticFileConversion::Data2VASP::Traj2XDAT_5_3_5->new($xdatcarOut),		# XDATCAR (Version 5.3.5) VASP trajectory format (no forces, no velocities, no time step, etc...)
	#'output' => AtomisticFileConversion::Data2VASP::Traj2XDAT_5_2_12->new($xdatcarOut),	# XDATCAR (Version 5.3.5) VASP trajectory format (no unit cell parameter updates, no forces, no velocities, no time step, etc...)

	# Materials Studio MDTR/trj
	#'output' => AtomisticFileConversion::Data2MS::Traj2XTD_MDTR_2010->new($fileOut),		# XTD_MDTR: Materials Studio via MDTR/tjr format (timestep, but issues with varying unit-cell parameters)

	# Materials Studio XTD -> uncomment library above if used
	#'output' => AtomisticFileConversion::Data2MS::Traj2XTD->new($trjName),					# XTD_MDTR: Materials Studio via MDTR/tjr format (timestep, but issues with varying unit-cell parameters)
	
	
	#### Optional trajectory frames slice...
	
	# Legend: [Step, End, Start]
	#'Steps'  => [1, -1, 2],
	#'Steps'  => [1, 0, 0], 
	
	# All frame numbers start at 0 -> perl array convention
	# Does not adopt perl convention on negative indexes -> Cannot use negative numbers to count backwards from end
	# Undef or omitted values will adopt defaults
	# End = -1 indicates last frame
});
	
