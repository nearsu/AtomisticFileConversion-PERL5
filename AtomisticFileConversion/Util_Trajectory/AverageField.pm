package AtomisticFileConversion::Util_Trajectory::AverageField;
        

use strict;
use warnings;

use AtomisticFileConversion::Util_Field qw(fieldSum fieldMultiply);
use AtomisticFileConversion::Util_Trajectory qw(firstStepTrajectory);

#use Exporter;
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
#$VERSION     = 1.00;
#@ISA         = qw(Exporter);
#@EXPORT      = ();
#@EXPORT_OK   = qw(new body DESTROY);


sub new{
	my ($className) = @_;
	my $self;

	$$self{'count'} = 0;
	
	bless $self, $className;
	return $self;
}


sub body {
	my ($self, $data, $stepsData) = @_;
	$$self{'data'} = $data if (firstStepTrajectory($stepsData));
	
	$$self{'count'}++;
	
	my $field = $$data{'field'};
	
	if (!defined($$self{'fieldSum'})){
		$$self{'fieldSum'} = $field;
	} else {
		fieldSum ($$self{'fieldSum'}, $field);
	}
	
	return undef;
}

sub DESTROY {
	my ($self) = @_;
	my $data = $$self{'data'};
	my $fieldSum = $$self{'fieldSum'};
	my $count = $$self{'count'};
	my $fieldAve = fieldMultiply ($fieldSum, (1/$count));
	$$data{'field'} = $fieldAve;
	delete $$data{'field1'};
	delete $$data{'field2'};
	delete $$data{'field3'};
	
	return ($data);
}


1;
