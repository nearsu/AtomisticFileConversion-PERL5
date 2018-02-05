package AtomisticFileConversion::Util_Trajectory::Combine;

use strict;
use warnings;
use Scalar::Util qw(blessed);

#use Exporter;
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
#$VERSION     = 1.00;
#@ISA         = qw(Exporter);
#@EXPORT      = ();
#@EXPORT_OK   = qw(new body DESTROY);


sub new{
	my ($className, $objects) = @_;
	my $self = $objects;
	
	die 'Expecting reference to an array of objects' unless ref $objects eq 'ARRAY';
	
	foreach my $object (@$self){
		unless (defined blessed $object){
			die 'Non-object passed to combine array arguement, did you really pass in objects?';
		}
	}
	
	bless $self, $className;
	return $self;	
}

sub body {
	my ($self, $args) = @_;
	
	my $data = {};
	
	foreach my $object (@$self){
		my $tempData = $object->body;
		return undef unless defined $tempData;
		die 'hash not returned as data' unless ref $tempData eq 'HASH';
		$data = {%$data, %$tempData};
	}
	
	return $data;
	
}


sub DESTROY {
	my ($self) = @_;
	return 1;
}



1;
