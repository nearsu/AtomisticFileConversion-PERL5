#!/usr/bin/perl

use strict;
use warnings;

#use lib '/my/path/to/libraries/';
use FindBin qw($Bin);
use lib "$Bin";
use AtomisticFileConversion::Data2VASP qw(DOSCAR2data);
use Scalar::Util qw(looks_like_number);

my ($folderInName, $fileOutName) = ('', 'DOS.dat');
my $fileInName = $folderInName.'DOSCAR';
my $vasprunName = $folderInName.'vasprun.xml';

die "No input file specified"  unless defined $fileInName;
open(my $fhIn, "<", $fileInName) or die "Can't open file: $!";

die "No input file specified"  unless defined $vasprunName;
open(my $fhInvasprun, "<", $vasprunName) or die "Can't open file: $!";


#### Put in subroutine...
# Adjust band energies with fermi energy...
my $fermiEnergy;
while (my $line = <$fhInvasprun>){
	next unless ($line =~ /name\=\"efermi\"/);
	$line =~ />(.+)</;
	my $energy = $1;
	$energy =~ s/^\s+//;
	$energy =~ s/\s+$//;
	die "fermi energy doesn't look like a number: $energy" unless looks_like_number($energy);
	$fermiEnergy = $energy*1;
	last;
}
#print "fermi energy: $fermiEnergy\n";

my $data = DOSCAR2data($fhIn);
#print Dumper $data;

# Adjust energies in DOS information...
foreach my $entry (@{$$data{'DOSArray'}}){
	$$entry[0] = $$entry[0] - $fermiEnergy;
}
#print Dumper $data;

# print out data...
die "No output file specified" unless defined $fileOutName;
open(my $fhOut, ">", $fileOutName) or die "Can't open file: $!";

foreach my $entry (@{$$data{'DOSArray'}}){
	foreach my $element (@$entry){
	print $fhOut $element, "\t";
	}
	print $fhOut "\n";
}
