package AtomisticFileConversion::Data2VASP::XDAT2traj;

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
	
	# Determine file type:
	my $position = tell ($fh);
	my $line    = Line ($fh);
	seek($fh, $position, 0);
	
	if (
		(defined ($line)) &&
		(defined ($$headerData{'header'})) &&
		($line eq $$headerData{'header'})
	){
		$$self{'fileType'} = '5.3.5';
	} else {
		$$self{'fileType'} = '5.2.12';
	};
	
	printf "Input XDATCAR File type detected: %s\n", $$self{'fileType'};
	
	bless $self, $className;
	return $self;	
}

sub body {
	my ($self, $args) = @_;
	my $fh = $$self{'fh'};
	
	
	if ($$self{'fileType'} eq '5.3.5'){
	
		
		my $data = CAR2data($fh);
		return $data;


	
	} elsif ($$self{'fileType'} eq '5.2.12'){
	

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
}




sub DESTROY {
	my ($self) = @_;
	my $fh = $$self{'fh'};
	close $fh or die "Can't close file: $!";
	return 1;
}



1;
