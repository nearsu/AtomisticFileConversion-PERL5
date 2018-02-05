#!/usr/bin/perl
# Must be run from within Materials Studio

use strict;
use warnings;
#use lib 'C:\My\Path\To\Libraries'; # Point to root folder containing the AtomisticFileConversion and Math folders
use FindBin qw($Bin);
use lib "$Bin";
use Storable qw(dclone);

use MaterialsScript qw(:all);

my $folderLocation = 'C:\My\Path\To\CHGCAR\Folder'; # File/folder containing the CHG file
my $xsdName = 'Structure';						# Name of xsd to create
my $defaultPoscarName = 'POSCAR';				# Name of POSCAR file
my $defaultChgcarName = 'CHGCAR';				# Name of CHGCAR file

# Clean/check folder location...
use AtomisticFileConversion::Util_System qw(fileFinder);
my $fileInformation = fileFinder($folderLocation, {
	'fileMode' 			=> 'READ',
	'defaultHandleType' => 'FOLDERNAME',
});
$folderLocation = $$fileInformation{'folder'};


#### Read files...
# VASP POSCAR, CONTCAR
use AtomisticFileConversion::Data2VASP qw(CAR2data);
my $data = CAR2data($folderLocation.$defaultPoscarName); 

# VASP CHGCAR
use AtomisticFileConversion::Data2VASP qw(CHG2data);
my $fieldData = CHG2data($folderLocation.$defaultChgcarName);

# Split fields away from data to be re-combined with main data one by one...
my $fields = {};
$$fields{'field'}  = $$fieldData{'field'};
$$fields{'field1'} = $$fieldData{'field1'};
$$fields{'field2'} = $$fieldData{'field2'};
$$fields{'field3'} = $$fieldData{'field3'};

delete $$fieldData{'field'};
delete $$fieldData{'field1'};
delete $$fieldData{'field2'};
delete $$fieldData{'field3'};


#### Write files...
# Materials Studio *.XSD (Needs Materials Studio installed)
use AtomisticFileConversion::Data2MS qw(Data2XSD);
my $doc = Data2XSD($xsdName, $data); # Name is plain text string without extension

# Load fields into Materials Studio	
foreach my $fieldName ('field', 'field1', 'field2', 'field3'){
	next unless defined $$fields{$fieldName};
	
	# Select field and delete the rest...
	my $fieldDataTemp = dclone ($fieldData);
	$$fieldDataTemp{'field'} = $$fields{$fieldName};
	$$fieldDataTemp{'header'} = $fieldName;
	
	## Materials Studio *.grd
	use AtomisticFileConversion::Data2Field qw(Data2GrdMS);
	my $msGrdFile = $folderLocation.$fieldName.'.grd';
	Data2GrdMS($msGrdFile, $fieldDataTemp);

	# Import *.grd onto *.xsd
	my $grid = $doc->InsertFrom($msGrdFile);
	
	# Adjust visible style to make visible
	my $field = $doc->AsymmetricUnit->Fields($fieldName);
	$field->Style = 'Volume';
	$field->IsHidden = 'No';
	
	# Clean up
	unlink ($msGrdFile);
}
