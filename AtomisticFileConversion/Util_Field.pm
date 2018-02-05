package AtomisticFileConversion::Util_Field;

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
@EXPORT_OK   = qw(fieldVoxels fieldSum fieldMultiply);



sub fieldVoxels {
	my ($fieldRef) = @_;
	my $fieldVoxels;
	foreach (0..2){
		push @$fieldVoxels, $#{$fieldRef};
		$fieldRef = $$fieldRef[0];
	}
	
	return $fieldVoxels;
}


sub fieldSum {
	my @fields = @_;	
	my $field = shift @fields;	
	my $fieldVoxels = fieldVoxels($field);
	
	foreach my $fieldSum (@fields){
		foreach my $i (0..$$fieldVoxels[0]){
		foreach my $j (0..$$fieldVoxels[1]){
		foreach my $k (0..$$fieldVoxels[2]){
			my $fieldValue = \$$field[$i][$j][$k];
			my $fieldSumValue = \$$fieldSum[$i][$j][$k];
			looks_like_number($$fieldValue) || 
				die "Field value not a number in fieldSum subroutine";
			looks_like_number($$fieldSumValue) || 
				die "Field value not a number in fieldSum subroutine";
			
			$$fieldValue += $$fieldSumValue;
		}}}
	}
}

sub fieldMultiply {
	my ($field, $constant) = @_;
	
	looks_like_number($constant) || 
		die "Field value not a number in fieldSum subroutine";
	
	my $fieldVoxels = fieldVoxels($field);
	
	foreach my $i (0..$$fieldVoxels[0]){
	foreach my $j (0..$$fieldVoxels[1]){
	foreach my $k (0..$$fieldVoxels[2]){
		my $fieldValue = \$$field[$i][$j][$k];
		looks_like_number($$fieldValue) || 
			die "Field value not a number in fieldSum subroutine";
		
		$$fieldValue *= $constant;
	}}}

	return $field;
}

1;
