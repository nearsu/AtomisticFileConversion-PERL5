#!/usr/bin/perl

use strict;
use warnings;
#use lib 'C:\My\Path\To\Libraries'; # Point to root folder containing the AtomisticFileConversion and Math folders
use FindBin qw($Bin);
use lib "$Bin";
use Storable qw(dclone);

my $folderLocation = 'C:\My\Path\To\CHGCAR';    # File/folder containing the CHGAR file
my $grdName = 'CHGCAR_';						# Names of grd to create
my $defaultChgcarName = 'CHGCAR';				# Name of CHGCAR file

# Clean/check folder location...
use AtomisticFileConversion::Util_System qw(fileFinder);
my $fileInformation = fileFinder($folderLocation, {
	'fileMode' 			=> 'READ',
	'defaultHandleType' => 'FOLDERNAME',
});
$folderLocation = $$fileInformation{'folder'};


#### Read VASP CHGCAR file...
use AtomisticFileConversion::Data2VASP qw(CHG2data);
my $fieldData = CHG2data($folderLocation.$defaultChgcarName);

# Split fields away from data to be re-combined with main data one by one -> save ram...
my $fields = {};
foreach my $fieldName ('field', 'field1', 'field2', 'field3'){
	$$fields{$fieldName}  = $$fieldData{$fieldName};
	delete $$fieldData{$fieldName};
};


#### Write *.grd files...
use AtomisticFileConversion::Data2Field qw(Data2Grd);
use AtomisticFileConversion::Data2Field qw(Data2GrdMS);

foreach my $fieldName ('field', 'field1', 'field2', 'field3'){
	next unless defined $$fields{$fieldName};
	
	# Select field and delete the rest...
	my $fieldDataTemp = dclone ($fieldData);
	$$fieldDataTemp{'field'} = $$fields{$fieldName};
	$$fieldDataTemp{'header'} = $fieldName;
	
	## Materials Studio *.grd
	my $msGrdFile = $folderLocation.$grdName.$fieldName.'_MS.grd';
	print $msGrdFile, "\n";
	Data2GrdMS($msGrdFile, $fieldDataTemp);

	my $vestaGrdFile = $folderLocation.$grdName.$fieldName.'_VESTA.grd';
	print $vestaGrdFile, "\n";
	Data2Grd($vestaGrdFile, $fieldDataTemp);
	
}
