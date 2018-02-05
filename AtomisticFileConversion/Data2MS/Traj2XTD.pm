package AtomisticFileConversion::Data2MS::Traj2XTD;
# Note: This library requires use of the Materials studio perl library
# Note: Therefore it must be used within the materials studio program

use strict;
use warnings;
use AtomisticFileConversion::Util_System qw(folderFileNameSplit directoryPathCleaner);
use AtomisticFileConversion::Data2MS qw(Data2XSD);
use MaterialsScript qw(:all);

#use Exporter;
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
#$VERSION     = 1.00;
#@ISA         = qw(Exporter);
#@EXPORT      = ();
#@EXPORT_OK   = qw(new body DESTROY);

sub new {
	my ($className, $xtdInput) = @_;
	my $data;
	my $doc;
	
	# Create or continue XTD file...
	
	if ((ref \$xtdInput) eq 'SCALAR'){ # Treat as name for new document...
		# Split file name, folders and extension and re-combine in appropriate fashion...
		my ($folder, $fileName, $extension) = folderFileNameSplit($xtdInput);
		$folder = directoryPathCleaner($folder);
		my $xtdName = $folder.$fileName.'.xtd';
		$doc = Documents->New($xtdName);
	}
	else { # Assume that data type is a trajectory document...
		$doc = $xtdInput;
	}
	
	$$data{'doc'} = $doc;
	
	bless $data, $className;
	return $data;
	
}

sub body {
	
	my ($dataHash, $data, $stepsData) = @_;
	
	# Header arguements...
	my $doc = $$dataHash{'doc'}; 

	my $index = $$stepsData{'StepValue'};  
	
	# File Body...
	# Convert data to XSD and push onto XTD...
	my $frame = Data2XSD("Frame $index", $data);
	$doc->Trajectory->AppendFramesFrom($frame);
	$frame->Delete;
	
	return undef;
	
}

sub DESTROY {
	my ($dataHash) = @_; 
	
	my $doc = $$dataHash{'doc'}; 
	$doc->Save;

	# Return XTD file...
	return $doc;

}



1;
