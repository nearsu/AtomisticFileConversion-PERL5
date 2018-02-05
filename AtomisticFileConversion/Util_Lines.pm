package AtomisticFileConversion::Util_Lines;

use strict;
use warnings;
use Math::Trig;
use List::Util qw(sum);
use Scalar::Util qw(looks_like_number);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(
	Field 
	Header 
	Line 
	number 
	array 
	vector
	Vectors
	UnitCell
	Chemicals
	Positions
);
%EXPORT_TAGS = (All => [qw(
	&Field 
	&Header 
	&Line 
	&number 
	&array 
	&vector
	&Vectors
	&UnitCell
	&Chemicals
	&Positions
)]);


sub Field {
	my ($fh) = @_;
	
	my $field;
	my $dimensions = vector($fh);
	#@$dimensions = reverse @$dimensions;
	
	
	my @data;
	
	foreach my $z (0..$$dimensions[2] - 1){
	foreach my $y (0..$$dimensions[1] - 1){
	foreach my $x (0..$$dimensions[0] - 1){
		# Load data when necessary...
		push @data, @{array($fh)} if ($#data == -1);
		
		my $data = shift @data;
		numberCheck($data);
		$$field[$x][$y][$z] = $data;
	}}}
	
	
	return {'field' => $field};
}

sub Header {
	my $line = Line (@_);
	return undef if (!defined $line);  
	
	return { 'header' => $line};
}

sub trim {
	my ($line) = @_;
	return undef if (!defined $line);
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	return $line;
}

sub Line {
	my ($fh) = @_;
	my $header = <$fh>;
	return undef if (!defined $header);
	$header = trim ($header);
	return $header;
	
}

sub numberCheck {
	foreach my $number (@_){		
		die "\'$number\' is not a number at line $." unless looks_like_number($number);
	}
}

sub number {
	my $number = Line (@_);
	numberCheck($number);
	return $number;
}


sub array {
	my ($fh) = @_;
	my $line = <$fh>;
	return undef if (!defined $line);
	$line = trim ($line);
	my @array = split (/\s+/, $line);
	return \@array;
}

sub vector {
	my $array = array(@_);
	return undef if (!defined $array);
	die "vector not 3 elements at line $." unless (($#{$array} + 1) == 3);
	numberCheck(@$array);
	#return Math::MatrixReal->new_from_cols([$array]);;
	return $array;
}

sub Vectors {
	my ($fh, $count) = @_;
	my @vectors;
	push @vectors, vector($fh) foreach (1..$count);
	return \@vectors;
}

sub UnitCell {
	my ($fh) = @_;
	return {
		'scalingFactor' => number($fh),
		'vectors' => Vectors($fh, 3)
	};
}

sub Chemicals {
	my ($fh) = @_;
	return {
		'chemicals' => array ($fh),
		'chemicalCounts' => array ($fh)
	};
}

sub Positions {
	my ($fh, $data) = @_;
	my $chemicalCounts = $$data{'chemicalCounts'};
	my $count = sum (@$chemicalCounts);
	die "Sum of chemicalCounts is not a number" unless looks_like_number($count);
	
	my $positionMethod = Line ($fh);
	return undef unless defined $positionMethod;
	
	my $positions = Vectors($fh, $count);
	return undef unless defined $positions;
	
	# Extra lines for XDATCAR frame number...
	my @positionMethod = split /\s+/, $positionMethod;
	if (
		(defined($positionMethod[1])) &&
		($positionMethod[1] eq 'configuration=')
	){
		$positionMethod = $positionMethod[0];
		my $frameStepNumber = $positionMethod[2];
		die 'Frame number not specified' unless looks_like_number($frameStepNumber);
		
		return {
			'positionMethod' => $positionMethod,
			'positions' => $positions,
			'frameStepNumber' => $frameStepNumber,
		}
	} else {
		return {
			'positionMethod' => $positionMethod,
			'positions' => $positions
		}
	}
}


1;
