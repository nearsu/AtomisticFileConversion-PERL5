package AtomisticFileConversion::Data2VASP::XDAT2traj_5_2_12;

use strict;
use warnings;
use AtomisticFileConversion::Util_Lines qw(:All);
use AtomisticFileConversion::Util_Trajectory qw(firstStepTrajectory);
use AtomisticFileConversion::Data2VASP qw(CAR2data);
use AtomisticFileConversion::Util_System qw(fileFinder);

#use Exporter;
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
#$VERSION     = 1.00;
#@ISA         = qw(Exporter);
#@EXPORT      = ();
#@EXPORT_OK   = qw(new body DESTROY);


sub new{
	my ($className,$fileIn) = @_;
	my $self;
	
	my $fileInformation = fileFinder($fileIn, {
		'fileMode' 			=> 'READ',			# -> Desired output - Manditory
		'defaultHandleType' => 'FILEHANDLE',	# -> Looking for input or output file if a file handle - Manditory
		'defaultName' 		=> 'XDATCAR',		# -> Default file name - Optional
	});
	my $fh = $$fileInformation{'fileHandle'};
	$$self{'fh'} = $fh;
	
	# Might like to open OUTCAR or other files to get more info like forces, velocities, etc...

	# Remove header -> Unnecessary...
	my $header    = Header ($fh);
	return undef if (!defined $header);
	
	my $unitCell  = UnitCell ($fh);
	my $chemicals = Chemicals ($fh);

	my $headerData = {
		%$header,
		%$unitCell,
		%$chemicals,
	};
	$$self{'headerData'} = $headerData;
	
	bless $self, $className;
	return $self;	
}

sub body {
	my ($self, $args) = @_;
	my $fh = $$self{'fh'};


	my $headerData = $$self{'headerData'}; 
	
	# Get table of positions...
	my $positions = Positions ($fh, $headerData);
		
	# Check data exists...
	if (defined $positions){
		
		# Get rid of unnecessary data...
		delete $$positions{'positionMethod'};
		
		# Put data together...
		my $data = {
			%$headerData,
			%$positions, 
		};
		
		# Send to next part...
		return $data;
	}
	
	# Else end...
	return undef;
}




sub DESTROY {
	my ($self) = @_;
	my $fh = $$self{'fh'};
	close $fh or die "Can't close file: $!";
	return 1;
}



1; 
