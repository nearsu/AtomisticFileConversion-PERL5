#!/usr/bin/perl
# Note: The input to most reading and writing subroutines accept file names, folder names (assuming default file name), or file handles
# Note: Relative or absolute paths are both OK

use strict;
use warnings;
#use lib 'C:\My\Path\To\Libraries'; # Point to root folder containing the AtomisticFileConversion and Math folders
use FindBin qw($Bin);
use lib "$Bin";


#### Read file...

# VASP CHGCAR (First frame only)
use AtomisticFileConversion::Data2VASP qw(CHG2data);
my $fileIn = 'C:\My\Path\To\CHGCAR'; # File/folder containing the POSCAR/CONTCAR file
my $data = CHG2data($fileIn);  


#### Write file...

# VESTA *.grd
use AtomisticFileConversion::Data2Field qw(Data2Grd);
my $fileOut1 = 'C:\My\Path\To\Output\gridVesta.grd'; # File containing the VESTA *.grd file
Data2Grd($fileOut1, $data);

## Materials Studio *.grd
use AtomisticFileConversion::Data2Field qw(Data2GrdMS);
my $fileOut2 = 'C:\My\Path\To\Output\gridMS.grd'; # File containing the Materials Studio compatible *.grd file
Data2GrdMS($fileOut2, $data);

