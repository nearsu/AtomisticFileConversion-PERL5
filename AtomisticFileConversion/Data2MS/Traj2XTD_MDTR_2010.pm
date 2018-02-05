package AtomisticFileConversion::Data2MS::Traj2XTD_MDTR_2010;
# Note: This library uses a binary executable from the Materials Studio program 
# Note: Therefore it must be executed on a computer with materials studio installed

use strict;
use warnings;

use Math::Complex;
use Math::Trig;
use Math::Trig ':pi';
use Scalar::Util qw(looks_like_number);
use AtomisticFileConversion::Util_ChemicalData qw(ConvertElementSymbol2Number);
use AtomisticFileConversion::Util_Math qw(convertVectors rotationAboutDirection_EulerParameters dot cross vectUnit rotationAboutDirection_CombineEulerParameters scalMult);
use AtomisticFileConversion::Util_System qw(folderFileNameSplit findMSBinDirectory directoryPathCleaner fileFinder);
use AtomisticFileConversion::Util_Trajectory qw(firstStepTrajectory);
use AtomisticFileConversion::Data2nonMS qw(Data2MSI);
use AtomisticFileConversion::Util_DataTransform qw(dataRotate);
use Storable qw(dclone);


sub new {
	my ($className, $folderOut) = @_;
	my $data;
	
	my $fileInformation = fileFinder($folderOut, {
		'fileMode' 			=> 'WRITE',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILENAME',	# -> Looking for input or output file if a file handle - Manditory
		#'defaultName' 		=> 'XDATCAR',		# -> Default file name - Optional
	});
	my $fileOutName = $$fileInformation{'fullPath'};
	
	# Break apart output directory and get full paths of all files...
	my ($folder, $fileName, $extension) = (
		$$fileInformation{'folder'},
		$$fileInformation{'fileName'},
		$$fileInformation{'extension'}
	);
	
	my $fullPath = $folder.$fileName;
	$$data{'fullPath'} = $fullPath;
	$$data{'fullPathTrj'} = $fullPath.'.trj';
	$$data{'fullPathMsi'} = $fullPath.'.msi';
	$$data{'fileOutName'} = $fileOutName;
	printf "OutputFile *.trj: %s\n", $$data{'fullPathTrj'};
	printf "OutputFile *.msi: %s\n", $$data{'fullPathMsi'};
	printf "OutputFile MDTR: %s\n", $$data{'fileOutName'};
	open(my $fhOutTxt, ">", $fileOutName) or die "Can't open file for writing: $!";
	$$data{'fh'} = $fhOutTxt;
	
	bless $data, $className;
	return $data;
}



sub body {
	
	my ($dataHash, $data, $stepsData) = @_;
	my $fhOutTxt = $$dataHash{'fh'};

	# Rotation of unit cell vectors to make Yy, Zy and Zz = 0
	# These values are not loaded by Materials Studio
	
	# Two rotations necessary
	# First:  Rotate all about Z x Zz by angle acos((Z dot Zz) / |Z|)    -> Rotates Z to Zz
	# Second: Rotate all about Zz by angle -> Rotates new Y to not point along x
	# Second rotation is performed after first -> must use updated Y coordinates
	
	# Header arguements...
	my $timeStep = 0;
	if (defined $$data{'timeStep'}){
		$timeStep = $$data{'timeStep'};
		#print "timeStep Found: $timeStep\n";
	};
	
	my $index = $$stepsData{'StepValue'}; 
	
	# Perform rotation due to bugs in code...
	if (firstStepTrajectory($stepsData)){
		# Need to perform rotation of all vector data to fix issues with non-loading of certain data points...
		print "\n";
		print "************************************************************************************************************************\n";
		print "                       MDTR/trj output file information\n";
		print "Warning: Unfortunately a rotation of the basis vectors must be performed before each frame is written to output to \n";
		print "Warning: make certain basis vector values equal to zero for reading into Materials Studio\n";
		print "Warning: An initial rotation is determined from the first frame and used for all remaining frames\n";
		print "Warning: Trajectories with fixed unit cell parameter will not be affected\n";
		print "Warning: However, if varying unit cell parameters are present in the simulation,\n";
		print "Warning: The absolute positions, forces, velocities, etc will be slightly wrong when the unit cell parameters change\n";
		print "Warning: This depends on how other programs read the data from the MDTR file,\n";
		print "Warning: Specifically, if they rely on the unit cell parameters\n";
		print "************************************************************************************************************************\n";
		print "\n";

		$$dataHash{'eulerRotation'} = determineEulerRotation($data);
			
	}
	
	$data = dataRotate($data, $$dataHash{'eulerRotation'});
	
	# First step initialisation...
	if (firstStepTrajectory($stepsData)){
		# Write MSI file...			
		Data2MSI($$dataHash{'fullPathMsi'}, $data);
		
		# Write MDTR header...
		Data2MDTR_Header($data, $fhOutTxt);
	}
	
	# File Body...
	my $totalTime = $timeStep*$index;
	Data2MDTR_Body($data, $fhOutTxt, $index, $totalTime, $timeStep);
	
	return undef;
}





sub DESTROY {
	my ($dataHash) = @_; 
	
	my $fileOutName = $$dataHash{'fileOutName'}; 
	my $fullPathTrj = $$dataHash{'fullPathTrj'}; 
	
	
	my $program;
	SECTION:{
		my $programFolder = findMSBinDirectory();
		#print Dumper $programFolder;
		print "Searching for Ascii2Trj.exe in Materials Studio directory...\n";
		foreach my $folder (@$programFolder){
			$program = $folder.'/Ascii2Trj.exe';
			print "Looking in: $program\n";
			last SECTION if -f $program;
		}
		my $text = '';
		$text .= "cannot find conversion program in $program, searched directories...\n";
		$text .= "$_\n" foreach (@$programFolder);
		die $text;
	}
	
	# Delete previous trj file...
	if (-f $fullPathTrj){
		unlink $fullPathTrj or die "Can't delete file: $!";
	};
	

	# Convert MDTR to trj...
	#### Add time out...
	#### Check file output size -> if not zero then OK...
	
	my $command = "\"$program\" \"$fileOutName\" \"$fullPathTrj\"";
	print "Command: $command\n";
	my $output = `$command`;
	die 'Conversion program error, Output: $output' if ($output);
	
	
	## Import into Materials Studio and delete originals
	#my $xtd = Documents->Import($fullPathTrj);
	##$xtd->Save;
	#return $xtd;
	
	return $fullPathTrj;
	
}


sub determineEulerRotation {
	my ($data) = @_;
	
	
	my $x = [1, 0, 0];
	my $y = [0, 1, 0];
	my $z = [0, 0, 1];
	
	## Step 1: Rotate C-direction along z-axis
	#my $unitCell = clone($$data{'vectors'});
	#die "No unit cell data in data structure" unless $unitCell;
	#
	#my $rotationAxis1  = vectUnit(cross($$unitCell[2], $z));
	#my $rotationAngle1 = Re(acos(dot(vectUnit($$unitCell[2]), $z)));
	##print Dumper $rotationAngle1;
	#my $eulerParameter1 = rotationAboutDirection_EulerParameters($rotationAxis1, $rotationAngle1);
	#
	## Step 2: Rotate around Z-axis until A is in Ax-Az plane
	#$data = dataRotate($data, $eulerParameter1);
	#$unitCell = clone($$data{'vectors'});
	#
	#my $rotationAxis2  = $z;
	#my $rotationAngle2 = Re(acos(dot(vectUnit([$$unitCell[0][0], $$unitCell[0][1], 0]), $x)));
	#my $eulerParameter2 = rotationAboutDirection_EulerParameters($rotationAxis2, $rotationAngle2);
	##$data = dataRotate($data, $eulerParameter2);
	


	# Step 1: Rotate C-direction along Z-axis
	my $unitCell = dclone($$data{'vectors'});
	die "No unit cell data in data structure" unless $unitCell;
	
	my $rotationAxis1  = vectUnit(cross($$unitCell[2], $z));
	my $rotationAngle1 = Re(acos(dot(vectUnit($$unitCell[2]), $z)));
	my $eulerParameter1 = rotationAboutDirection_EulerParameters($rotationAxis1, $rotationAngle1);
	
	# Step 2: Rotate around Z-axis until B is in By-Bz plane
	$data = dataRotate($data, $eulerParameter1);
	$unitCell = dclone($$data{'vectors'});
	
	my $rotationAxis2  = scalMult($z, -1); #Rotation in wrong direction fixed here...
	my $rotationAngle2 = Re(acos(dot(vectUnit([$$unitCell[1][0], $$unitCell[1][1], 0]), $y)));
	my $eulerParameter2 = rotationAboutDirection_EulerParameters($rotationAxis2, $rotationAngle2);
	
	#$data = dataRotate($data, $eulerParameter2);
	#$unitCell = dclone($$data{'vectors'});

	#return rotationAboutDirection_EulerParameters($x, 0);
	#return $eulerParameter1;
	return rotationAboutDirection_CombineEulerParameters($eulerParameter1, $eulerParameter2);
}



sub Data2MDTR_Header {
	my ($data, $fh) = @_;
	
	# Get total number of atoms...
	my $totalAtoms;
	{
		# Get atoms and counts...
		my @atoms      = @{$$data{'chemicals'}};
		my @atomCounts = @{$$data{'chemicalCounts'}};
		die "Different number of elements and element counts" if ($#atoms != $#atomCounts);
		$totalAtoms += $_ foreach @atomCounts;
	}
	
	print $fh "Header:	MDTR\n";
	print $fh "Control:	 2010     0     0     0     0     0     0     0     0     0 \n";
	print $fh "        	    0     0     0     0     0     0     0     0     0     0 \n";
	print $fh "No Comments:	 1\n";
	#print $fh "COMMENT: Trajectory created by AtomisticFileConversion script see github \n"; # Note: MS reads these comments...
	print $fh "COMMENT: Trajectory created by MatStudio CASTEP                                          \n";
	print $fh "No EEX Comments:	 1\n";
	#print $fh "COMMENT: Trajectory created by AtomisticFileConversion script see github \n"; # Note: MS reads these comments...
	print $fh "COMMENT: Quantum-mechanical CASTEP calculation                                           \n";
	print $fh "Periodicity:	3\n";
	print $fh "MolXtl:		F\n";
	print $fh "Canonical:	F\n";
	print $fh "DefCel:		F\n";
	print $fh "PertTheory:	F\n";
	print $fh "NoseOrHoover:	F\n";
	print $fh "NpTCanon:	F\n";
	print $fh "TempDamping:	F\n";
	print $fh "FilNum: 1	Movatms:      $totalAtoms TotAtms:      $totalAtoms Descriptor: MStudio \n";
	print $fh "Atom Ids:	   ";
	#print $fh "$_ " foreach (1..$totalAtoms); #### Might need to wrap this line...
	
	foreach my $atomIndex (1..$totalAtoms){
		print $fh "   $atomIndex ";
		print $fh "\n\t" if ((($atomIndex + 1) % 10) == 0);
	}
	#39    40    41    42    43    44    45    46    47    48 
	#	   49    50    51    52    53    54    55    56    57    58 
	#	   59    60    61    62    63    64    65    66    67    68 
	#	   69    70    71    72    73    74    75    76    77    78 
	#	   79    80    81    82    83    84    85    86     1     2 
	#	    3     4     5     6     7     8     9    10    11    12 
	#	   13    14    15    16    17    18    19    20    21    22 
	#	   23    24    25    26    27    28    29    30    31    32 
	#	   33    34    35    36    37    38 
	print $fh "\n";
	print $fh "EEX Title: NOTITLE\n";
	print $fh "Parameter File: NOPAR\n";
	
	
	
}


sub Data2MDTR_Body {

	my ($data, $fh, $index, $totalTime, $timeStepSize) = @_;
	
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
	my $atomicVelocities = $$data{'velocities'};
	my $atomicForces = $$data{'forces'};
	
	# Note: There may still be velocities and the like remaining in the file...
	
	## Write output
	
	# Header
#Frame Number: 2
#Time/Energy:	 1.0000000043195990e-003                       2  1.0914535906299552e+003
#	 1.0914535906299552e+003  1.0000000043195990e-003  0.0000000000000000e+000
#	 0.0000000000000000e+000 -1.4806911169420772e+006  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000 -1.4806911169420772e+006
#	 0.0000000000000000e+000 -1.4806911169420772e+006  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000 -1.4806911169420772e+006
#	 0.0000000000000000e+000 -1.4804145766240512e+006  2.7654031802593414e+002
#	-1.4804145766240512e+006  2.7654031802593414e+002                       0
#	                      0                       F                       T
#	                      0                       0
#Pressure: 0.0000000000000000e+000  9.4490545727535596e+002  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  9.4490545727535596e+002  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#DefCell:	 0.0000000000000000e+000  0.0000000000000000e+000
#	 8.6487000080549876e+000  9.9866585555817249e+000  1.0940000010188987e+001
#	 1.0000000009313517e-015  1.0000000009313517e-015 -4.9933292777908660e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#Period:	                     86
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000
#Rwp:	0.0000 



#Frame Number: $index+1
#Time/Energy:	 $totalTime                       $index+1  $energy
#	 $energy  $timeStepSize  0.0000000000000000e+000
#	 0.0000000000000000e+000 $potentialEnergy  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000 $potentialEnergy
#	 0.0000000000000000e+000 $potentialEnergy  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000 $potentialEnergy
#	 0.0000000000000000e+000 $variable1  $variable2
#	$variable1  $variable1                       0
#	                      0                       T                       T
#	                      0                       0
#Pressure: 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#DefCell:	 0.0000000000000000e+000  0.0000000000000000e+000
#	 A_a  B_b  C_c
#	 B_z  A_z A_b
#	 C_b?  C_z!?  A_Z!? #### Cannot reproduce these lines...
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#Period:	                     86
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000
#	 0.0000000000000000e+000  0.0000000000000000e+000
#Rwp:	0.0000 
	
	my $energy = 0;
	my $potentialEnergy = 0;
	my $variable2 = 0;
	my $indexPP = $index + 1;
	printf $fh "Frame Number: $indexPP\n";
	printf $fh "Time/Energy:	 %.16e                       %s  %.16e\n", $totalTime, $indexPP, $energy;
	printf $fh "	 %.16e  %.16e  0.0000000000000000e+000\n", $energy,  $timeStepSize;
	printf $fh "	 0.0000000000000000e+000 %.16e  0.0000000000000000e+000\n", $potentialEnergy;
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000 %.16e\n", $potentialEnergy;
	printf $fh "	 0.0000000000000000e+000 %.16e  0.0000000000000000e+000\n", $potentialEnergy;
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000 %.16e\n", $potentialEnergy;
	printf $fh "	 0.0000000000000000e+000 %.16e  %.16e\n", $potentialEnergy,  $variable2;
	printf $fh "	%.16e  %.16e                       0\n", $potentialEnergy, $variable2;
	printf $fh "	                      0                       F                       T\n";   # T/F switches may refer to Velocities/Forces sections existance below...
	printf $fh "	                      0                       0\n";
	printf $fh "Pressure: 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "DefCell:	 0.0000000000000000e+000  0.0000000000000000e+000\n";
	
	# Have to perform a rotation on the unit cell vectors to change the last 3 entries to effectively zero, see other parts of script
	printf $fh "	 %.16e %.16e %.16e\n", $$unitCell[0][0], $$unitCell[1][1], $$unitCell[2][2];
	printf $fh "	 %.16e %.16e %.16e\n", $$unitCell[1][2], $$unitCell[0][2], $$unitCell[0][1];
	printf $fh "	 %.16e %.16e %.16e\n", $$unitCell[2][1], $$unitCell[2][0], $$unitCell[1][0]; #### Cannot reproduce this line, all values in this line should all be zero... 
	#printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";

	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "Period:	                    %s \n", $totalAtoms;
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "	 0.0000000000000000e+000  0.0000000000000000e+000\n";
	printf $fh "Rwp:	0.0000 \n";



	# Write coordinates...
	
	printf $fh "Coordinates:";
	foreach my $index (0..$#$atomicVectors){
		my $vector = $$atomicVectors[$index];
		foreach my $i (0..2){
			$$vector[$i] = 0 unless defined $$vector[$i];
		}
		
		my $cartVector = convertVectors($unitCell, $vector);
		printf $fh "	       %s  %.16e  %.16e  %.16e \n", $index+1, $$cartVector[0], $$cartVector[1], $$cartVector[2];
	}
	
	#printf $fh "Velocities:";
	#foreach my $index (0..$#$atomicVectors){
	#	#my $element = $atomKey[$index];
	#	my $velocities = $$atomicVelocities[$index];
	#	foreach my $i (0..2){
	#		$$velocities[$i] = 0 unless defined $$velocities[$i];
	#	}
	#	#my $cartVector = convertVectors($unitCell, $vector);
	#	printf $fh "	       %s  %.16e  %.16e  %.16e \n", $index+1, $$velocities[0], $$velocities[1], $$velocities[2];
	#}
	
	printf $fh "Forces:";
	foreach my $index (0..$#$atomicVectors){
		#my $element = $atomKey[$index];
		my $forces = $$atomicForces[$index];
		foreach my $i (0..2){
			$$forces[$i] = 0 unless defined $$forces[$i];
		}
		#my $cartVector = convertVectors($unitCell, $vector);
		printf $fh "	       %s  %.16e  %.16e  %.16e \n", $index+1, $$forces[0], $$forces[1], $$forces[2];
	}
	
}





1;
