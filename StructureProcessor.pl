#!/usr/bin/perl
# Note: The input to most reading and writing subroutines accept file names, folder names (assuming default file name), or file handles
# Note: Relative or absolute paths are both OK

use strict;
use warnings;
#use lib 'C:\My\Path\To\Libraries'; # Point to root folder containing the AtomisticFileConversion and Math folders
use FindBin qw($Bin);
use lib "$Bin";


#### Read file...

# VASP POSCAR, CONTCAR
use AtomisticFileConversion::Data2VASP qw(CAR2data);
my $fileIn = 'C:\My\Path\To\POSCAR'; # File/folder containing the POSCAR/CONTCAR file
my $data = CAR2data($fileIn); 

## Materials Studio *.XSD (Needs Materials Studio installed)
#use AtomisticFileConversion::Data2MS qw(XSD2data);
#use MaterialsScript qw(:all);
#my $fileInName = 'Structure.xsd';
#my $docInput = $Documents{$fileInName};
#my $data = XSD2data($docInput); # Input is XSD document


#### Write file...

# VASP POSCAR, CONTCAR
use AtomisticFileConversion::Data2VASP qw(Data2CAR);
my $fileOut1 = 'C:\My\Path\To\Output\POSCAR'; # File/folder containing the POSCAR/CONTCAR file
Data2CAR($fileOut1, $data);

## Materials Studio *.msi (OUT only)
#use AtomisticFileConversion::Data2nonMS qw(Data2MSI);
#my $fileOut2 = 'C:\My\Path\To\Output\structure.msi'; # File containing the *.msi file
#Data2MSI($fileOut2, $data);

## Materials Studio *.XSD (Needs Materials Studio installed)
#use AtomisticFileConversion::Data2MS qw(Data2XSD);
#my $xsdName = 'Structure';
#my $docOutput = Data2XSD($xsdName, $data); # Name is plain text string without extension

