#!/usr/bin/perl

use strict;
use warnings;

#use lib '/my/path/to/libraries/';
use FindBin qw($Bin);
use lib "$Bin";
use AtomisticFileConversion::Data2VASP qw(CHGMD2AverageField);
use AtomisticFileConversion::Data2Field qw(Data2Grd);

#my ($fileInName, $fileOutName) = @ARGV;
my ($fileInName, $fileOutName) = ('C:\path\to\CHG', 'C:\path\to\CHG_Average.grd');


die "No input file specified"  unless defined $fileInName;
open(my $fhIn, "<", $fileInName) or die "Can't open file: $!";
my ($fieldAve, $trajectory, $count) = CHGMD2AverageField($fhIn);

# Put field with first frame CS
my $data = $$trajectory[0];
$$data{'field'} = $fieldAve;

die "No output file specified" unless defined $fileOutName;
open(my $fhOut, ">", $fileOutName) or die "Can't open file: $!";
Data2Grd($fhOut, $data);
