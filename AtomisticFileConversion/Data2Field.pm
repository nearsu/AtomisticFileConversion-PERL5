package AtomisticFileConversion::Data2Field;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use AtomisticFileConversion::Util_Math qw(vectors2angles scaleVectors);
use AtomisticFileConversion::Util_Field qw(fieldVoxels);
use AtomisticFileConversion::Util_System qw(fileFinder);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(Data2Grd Data2GrdMS);



sub Data2Grd {
	my ($fh, $data, $materialsStudio) = @_;
	my $fileInformation = fileFinder($fh, {
		'fileMode' 			=> 'WRITE',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
	});
	$fh = $$fileInformation{'fileHandle'};

	if (!exists $$data{'lengths'}){
		my $vectors = $$data{'vectors'};
		my $scalingFactor = $$data{'scalingFactor'};
		
		$vectors = scaleVectors($vectors, $scalingFactor);		
		
		my $anglesLengths = vectors2angles($vectors);
		%$data = (%$data, %$anglesLengths); 
	}
	
	field2Grd($fh, $$data{'field'}, $data, $materialsStudio);
}

sub Data2GrdMS {
	my ($fh, $data) = @_;
	my $fileInformation = fileFinder($fh, {
		'fileMode' 			=> 'WRITE',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
	});
	$fh = $$fileInformation{'fileHandle'};

	
	if (!exists $$data{'lengths'}){
		my $vectors = $$data{'vectors'};
		my $scalingFactor = $$data{'scalingFactor'};
		
		$vectors = scaleVectors($vectors, $scalingFactor);		
		
		my $anglesLengths = vectors2angles($vectors);
		%$data = (%$data, %$anglesLengths); 
	}
	
	
	field2Grd($fh, $$data{'field'}, $data, 1);
}



sub field2Grd {
	my ($fh, $field, $hash, $materialsStudio) = @_;
	
	$materialsStudio = 0 
		unless (
			(defined $materialsStudio) &&
			($materialsStudio == 1)
	);
	
	my $fieldVoxels = fieldVoxels($field);
	
	my $lengths = $$hash{'lengths'};
	my $angles = $$hash{'angles'};
	
	if ($materialsStudio == 1){
		# Materials Studio Header...
		printf $fh "%s\n", $$hash{'header'};
		printf $fh "%s\n", ' (1F5.0)';
		printf $fh " %s", $_ foreach (@$lengths);
		printf $fh " %s", $_ foreach (@$angles);
		printf $fh "\n";
		printf $fh " %i", ($_ + 1) foreach (@$fieldVoxels);
		printf $fh "\n";
		printf $fh " 1";
		printf $fh " 0 %i", ($_ + 1) foreach (@$fieldVoxels);
		printf $fh "\n";
		
		# Content...
		foreach my $k (0..$$fieldVoxels[2], 0){
		foreach my $j (0..$$fieldVoxels[1], 0){
		foreach my $i (0..$$fieldVoxels[0], 0){
			my $value = $$field[$i][$j][$k];
			looks_like_number($value) || 
				die "Field value not a number in field subroutine";
			
			printf $fh "%s\n", $value;
			
		}}}

		
	} else {
		# Vesta header...
		printf $fh "%s\n", $$hash{'header'};
		printf ($fh "%s\n", $_) foreach (@$lengths);
		printf ($fh "%s\n", $_) foreach (@$angles);
		printf $fh " %i", ($_ + 1) foreach (@$fieldVoxels);
		printf $fh "\n";
		
		# Content...
		foreach my $i (0..$$fieldVoxels[0]){
		foreach my $j (0..$$fieldVoxels[1]){
		foreach my $k (0..$$fieldVoxels[2]){
			my $value = $$field[$i][$j][$k];
			looks_like_number($value) || 
				die "Field value not a number in field subroutine";
			
			printf $fh "%s\n", $value;
			
		}}}
	}
	
	
}


1;
