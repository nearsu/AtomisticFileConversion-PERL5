package AtomisticFileConversion::Util_Trajectory::FixedData;

use strict;
use warnings;

use Data::Dumper; ####
use Scalar::Util qw(blessed);

#use Exporter;
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
#$VERSION     = 1.00;
#@ISA         = qw(Exporter);
#@EXPORT      = ();
#@EXPORT_OK   = qw(new body DESTROY);


sub new{
	my ($className, $data) = @_;
	my $self = {'data' => $data};
	
	bless $self, $className;
	return $self;	
}

sub body {
	my ($self, $args) = @_;
	my $data = $$self{'data'};
	return $data;
}




sub DESTROY {
	my ($self) = @_;
	return 1;
}



1;
