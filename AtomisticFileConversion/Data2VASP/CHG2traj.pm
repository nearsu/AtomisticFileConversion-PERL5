package AtomisticFileConversion::Data2VASP::CHG2traj;

use strict;
use warnings;
use AtomisticFileConversion::Data2VASP qw(CHG2data);
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
		'defaultName' 		=> 'CHG',			# -> Default file name - Optional
	});
	
	my $fh = $$fileInformation{'fileHandle'};
	$$self{'fh'} = $fh;
	
	bless $self, $className;
	return $self;	
}

sub body {
	my ($self, $args) = @_;
	my $fh = $$self{'fh'};
	
	return CHG2data($fh);
	
}

sub DESTROY {
	my ($self) = @_;
	my $fh = $$self{'fh'};
	close $fh or die "Can't close file: $!";
	return 1;
}

1;
