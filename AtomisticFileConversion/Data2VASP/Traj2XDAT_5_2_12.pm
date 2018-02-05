package AtomisticFileConversion::Data2VASP::Traj2XDAT_5_2_12;

use strict;
use warnings;

use AtomisticFileConversion::Util_Lines qw(:All);
use AtomisticFileConversion::Util_Trajectory qw(firstStepTrajectory);
use AtomisticFileConversion::Data2VASP qw(Data2CAR_Header Data2CAR_Body);
use AtomisticFileConversion::Util_System qw(fileFinder);

#use Exporter;
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
#$VERSION     = 1.00;
#@ISA         = qw(Exporter);
#@EXPORT      = ();
#@EXPORT_OK   = qw(new body DESTROY);


sub new{
	my ($className,$fileOut) = @_;
	my $self;
	
	my $fileInformation = fileFinder($fileOut, {
		'fileMode' 			=> 'WRITE',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=> 'XDATCAR',		# -> Default file name - Optional
	});
	my $fh = $$fileInformation{'fileHandle'};
	
	$$self{'fh'} = $fh;
	$$self{'ionicStep'} = 0;
	
	bless $self, $className;
	return $self;
}


sub body {
	my ($self, $data, $stepsData) = @_;
	my $fh = $$self{'fh'};
	
	
	# First step initialisation...
	# Write header...
	Data2CAR_Header($fh, $data) if (firstStepTrajectory($stepsData));
	
	# Write body...
	Data2CAR_Body($fh, $data, 1);
	
	return undef;
}

sub DESTROY {
	my ($self) = @_;
	my $fh = $$self{'fh'};

	# Close file...
	close $fh or die "Can't close file: $!";
	
	return 1;
}





1;
