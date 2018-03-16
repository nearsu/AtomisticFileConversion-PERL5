package AtomisticFileConversion::Util_System;

use strict;
use warnings;
use File::Spec;
use Scalar::Util qw(looks_like_number openhandle);
use Switch;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(timeOutWrapper folderFileNameSplit directoryPathCleaner findMSBinDirectory fileFinder);


my %mode = (
	'READ' => '<',
	'WRITE' => '>',
	'APPEND' => '>>',
);


sub timeOutWrapper {
	my ($timeout, $subroutine, $input) = @_;
	my @answer;
	eval {
		local $SIG{ALRM} = sub { die "alarm\n" };
		alarm $timeout;
		@answer = &{$subroutine}(@$input);
		alarm 0;
	};
	if ($@){
		die unless $@ eq "alarm\n";
		die "\nTimed_Out\n";
	} else {
		return @answer;
	}
}



sub folderFileNameSplit {
	my ($name, $folderSwitch) = @_;
	
	# Break apart output directory into folder path, file name without extension and extension
	my ($volume,$directories,$file) = File::Spec->splitpath($name, $folderSwitch);
	my $folder = $volume.$directories;
	
	my ($extension) = $file=~/(\.[^.]*$)/;
	my $fileName = $file;
	if (defined ($extension)){
		($fileName) = $file=~/(.*)$extension$/;
	} else {
		$extension = '';
	}
	
	return ($folder, $fileName, $extension);
}



sub directoryPathCleaner {
	my ($inputString) = @_;
	
	return '' if $inputString eq '';
	
	# Put a / on the end of the string
	$inputString = $inputString.'/';
	
	# Convert all /\ to /'s
	$inputString =~ s/\\/\//g;
	
	# Concatenate all multiple ///'s to a single /
	$inputString =~ s/\/+/\//g;
	
	return $inputString;
}


sub findMSBinDirectory {
	
	my @extraGuesses;
	
	{
		#C:\Program Files (x86)\Accelrys\Materials Studio 6.0\bin
		my $folderAccelrys = 'C:\Program Files (x86)\Accelrys\\';
		my $subfolderAccerlys = '\lib';
		
		if (-d $folderAccelrys){
			opendir(my $directory, $folderAccelrys) || die "Can't open directory: $!\n";
			
			my $version = 0;
			my $fullPath;
			
			while (my $file = readdir($directory)) {
				
				my $subfolder = $folderAccelrys.$file;
				
				next unless (-d $subfolder);
				
				next unless $file =~ /^Materials Studio (.+)$/;
				my $remainingString = $1;
				
				my @remainingString = split /\s+/, $remainingString;
				
				next unless ($#remainingString == 0);
				
				next unless looks_like_number($remainingString[0]);
				
				next unless ($version < $remainingString[0]);
				
				$version = $remainingString[0];
				$fullPath = $subfolder.$subfolderAccerlys;
				
			}
			closedir($directory);
			
			push @extraGuesses, $fullPath
				if (defined ($fullPath));
		
		}
	}
	
	{
		#C:\Program Files (x86)\BIOVIA\Materials Studio 17.2\bin
		my $folderAccelrys = 'C:\Program Files (x86)\BIOVIA\\';
		my $subfolderAccerlys = '\lib';
		
		if (-d $folderAccelrys){
			opendir(my $directory, $folderAccelrys) || die "Can't open directory: $!\n";
			
			my $version = 0;
			my $fullPath;
			
			while (my $file = readdir($directory)) {
				
				my $subfolder = $folderAccelrys.$file;
				
				next unless (-d $subfolder);
				
				next unless $file =~ /^Materials Studio (.+)$/;
				my $remainingString = $1;
				
				my @remainingString = split /\s+/, $remainingString;
				
				next unless ($#remainingString == 0);
				
				next unless looks_like_number($remainingString[0]);
				
				next unless ($version < $remainingString[0]);
				$version = $remainingString[0];
				$fullPath = $subfolder.$subfolderAccerlys;
				
			}
			closedir($directory);
			push @extraGuesses, $fullPath
				if (defined ($fullPath));
		}
	}

	my @paths;
	{
		my %paths;
		foreach my $path (@INC, @extraGuesses){
			my ($string) = $path =~ /^(.+mater.+lib)/i; # Search for materials studio lib folder(s)
			next unless defined $string;
			
			$string = directoryPathCleaner($string);
			my $directorySeparator = chop($string); # Remove trailing slash added from above...
			my @folders = split /$directorySeparator/, $string;
			next unless $folders[-2] =~ /^mater/i; # is previous directory the 'MaterialsStudio...' directory?
			
			next unless (-d $string);
			
			$paths{$string} = 1;
		}

		@paths = keys %paths;
	}

	my @outputPaths;

	foreach my $path (@paths){
		next unless ($path =~ s/lib$/bin/i);
		next unless (-d $path);
		push @outputPaths, $path;
	}
	
	return (\@outputPaths);

}



sub handleRef {
	my ($fh, $dataTypeHash) = @_;

	# Folder test...
	
	# Issues here...
	# See https://www.perlmonks.org/?node_id=1208018 for more details...
	# May need to be updated if the bug ever gets fixed
	
	#eval{-d $handle};
	#if($@ =~ /dirfd function is unimplemented/) {
	#	# then you know $handle is a dirhandle
	#}
	#elsif($@) {
	#	die $@; # a different problem
	#}
	
	return 'UNDEF' unless defined $fh;
	my $folderType = eval {
		no warnings;
		telldir ($fh);
	};
	if (looks_like_number($folderType)){
		$folderType = 1;
	} else {
		$folderType = 0;
	}
	return 'FOLDERHANDLE' if ($folderType);
	
	# File test (Test to see if thing can be used as a file handle and is open, -f is too specific)...
	my $handleType = openhandle($fh);
	return 'FILEHANDLE' if (openhandle($fh));
	
	# Everything else...
	return ref \$fh;
}


sub handleAnalyser {
	my ($fh, $defaultName, $inputStringType, $fileInOut, $defaultHandleType) = @_;
	#print Dumper ('$inputStringType', $inputStringType);
	my $handleRef = handleRef($fh);
	#print Dumper \$fh;
	#print Dumper $handleRef;
	switch ($handleRef){
		case 'FILEHANDLE'	{ return 'FILEHANDLE'	}
		case 'FOLDERHANDLE'	{ return 'FOLDERHANDLE'	}
		case 'SCALAR' 		{
			# Determine if string is a file or a folder description
			# Note: files and folders cannot have the same name on sane disk structures
			# **** Check to see if path needs to be added to these descriptions or not...
			
			# return folder if zero-length string detected -> refers to current directory!?
			return 'FOLDERNAME' if ($fh eq '');
			
			# Check if folder or file already exists? Then that is what it is
			return 'FILENAME' if (-f $fh);
			return 'FOLDERNAME' if (-d $fh);
			
			# If no input file was found, then die
			die "Input file string does not exist as either a file or folder: $fh" if ($fileInOut eq 'READ');
			
			# If output is required, string could be a file description or a folder description...
			
			# Is there a slash at the end of the file string? -> Folder
			return 'FOLDERNAME' if ($fh =~ m{[/\\]$}); #Buggy line
			
			# Is the last part of the folder description the same as the default file name? -> File
			# Buggy, should make sure that the default file name is not a folder!? -> Concatenation of folder and file could lead to another folder!?
			# Possibly just crash if separator found in file name!?
			if (
				defined ($defaultName) &&
				($fh =~ m{[/\\]$defaultName$}) # Buggy line
			){
				return 'FILENAME';
			}
			
			# Manual forcing of file type if none of the above tests work
			if (defined $inputStringType){
				switch ($inputStringType){
					case 'FILE'		{ return 'FILENAME';	}
					case 'FOLDER'	{ return 'FOLDERNAME';	}
					else			{ die "inputStringType is not either FILE or FOLDER";	}
				}
			}
			
			# If none of the above works, then assume that it is either file or folder based on what is requested by the calling sub-routine...
			# Other option is just to default to file description and allow terminating '\' or '/' to determine whether the string is talking about a folder or file
			
			switch ($defaultHandleType){
				case 'FILEHANDLE'	{ return 'FILENAME'; }
				case 'FOLDERHANDLE'	{ return 'FOLDERNAME'; }
				case 'FILENAME'		{ return 'FILENAME'; }
				case 'FOLDERNAME'	{ return 'FOLDERNAME'; }
				else 				{ die 'defaultHandleType is not either FILEHANDLE, FOLDERHANDLE, FILENAME or FOLDERNAME'}
			}
		}

		else	{ die "Input file handle is not an open file handle, folder handle or a scalar describing a file or folder, type: ", handleRef($fh) }
	}
	
	die 'Cannot analyse file handle';

}



sub fileFinder {
	# Purpose of subroutine:
	# Unified subroutine for handling automatic finding, naming and opening of files for reading and writing
	
	# Input: File handle, folder handle, file name or folder name
	# Input: Default file name, default file type as hash, file opened for input or output, inputStringType
	# Some of the above are optional depending on what is requested and what is provided
	
	# Output: File handle, folder handle, file name or folder name, as requested by caller if possible...
	# Output: Other information such as full file name including path, folder path, file name without extension, extension, file name with extension, file path and file name without extension, anything else...
	
	# Problem with possibility of handing in a file handle but needing a folder name in return, will cause an error...
	
	# Also, problem with interpretation of what is a file handle or not, see the following links...
	# http://www.perlmonks.org/?node_id=980665
	# https://stackoverflow.com/questions/3214647/what-is-the-best-way-to-determine-if-a-scalar-holds-a-filehandle
	# https://stackoverflow.com/questions/3807231/how-can-i-test-if-i-can-write-to-a-filehandle/4200474#4200474
	# Apparently using openhandle does not work very well for all types of file handles and situations
	# However, hopefully it will work OK for this situation...
	
	my ($fh, $dataTypeHash) = @_;
	my $outputData = {};
	
	## Validate input data
	
	my $defaultName;
	#die 'defaultName not specified' unless defined $$dataTypeHash{'defaultName'} -> Only necessary if required
	#my $defaultName = $$dataTypeHash{'defaultName'};
	if (defined $$dataTypeHash{'defaultName'}){
		$defaultName = $$dataTypeHash{'defaultName'};
		die 'defaultName not a string' unless ((ref \$defaultName) eq 'SCALAR');
		# Name should be validated here possibly using valid_filename from File::Util but can't use modules unfortunatley
	}
	
	die 'fileInOut not specified' unless defined $$dataTypeHash{'fileMode'};
	my $fileInOut = $$dataTypeHash{'fileMode'};
	switch ($fileInOut){
		case 'READ'		{}
		case 'WRITE'		{}
		case 'APPEND' 	{}
		else			{	die "fileInOut is not either IN, OUT or APPEND";	}
	}
	
	die 'defaultHandleType not specified' unless defined $$dataTypeHash{'defaultHandleType'};
	my $defaultHandleType = $$dataTypeHash{'defaultHandleType'};
	switch ($defaultHandleType){
		case 'FILEHANDLE'	{}
		case 'FOLDERHANDLE'	{}
		case 'FILENAME'		{}
		case 'FOLDERNAME'	{}
		else 				{die 'defaultHandleType is not either FILEHANDLE, FOLDERHANDLE, FILENAME or FOLDERNAME'}
	}
	
	my $inputStringType;
	if (defined $$dataTypeHash{'inputStringType'}){
		$inputStringType = $$dataTypeHash{'inputStringType'};
		switch ($inputStringType){
			case 'FILE'		{}
			case 'FOLDER'	{}
			else			{	die "inputStringType is not either FILE or FOLDER";	}
		}
	}
	
	
	## Determine what type of data was handed to subroutine
	my $handleType = handleAnalyser($fh, $defaultName, $inputStringType, $fileInOut, $defaultHandleType);
	$$outputData{'detectedHandleType'} = $handleType;
	#print Dumper $handleType;
	#return $handleType;
	
	
	
	## Process input and output data
	# -> Pass through handles if they match the default handle type, else...
	# -> Produce folder paths if possible
	# -> open file/folder handles if requested
	# -> Test handles to see if they will do what you want them to -> read/write/parse folders, etc...


	
	
	# Re-write using File::Spec some more to handle folder names...
	
	# -> Produce folder paths if possible
	if (
		$handleType eq 'FILENAME' ||
		$handleType eq 'FOLDERNAME'
	){
		# Need to produce the following data...
		# -> Absolute and/or relative!? -> Just divide the given data accordingly
		# Full path including everything
		# Folder path with separator on end
		# Name with extension
		# Name without extension
		# Extension
		
		#my $fullPath = $fh;
		
		if ($handleType eq 'FOLDERNAME'){
			
			# Possibly fix issues with blank folder being interpreted as a file due to no slashed in name
			$fh = './' if $fh eq ''; 
			
			# Add end of string separator if necessary...
			$fh .= '/' unless ((substr ($fh, -1, 1)) =~ m[/\\]);
		
			# Add file name if necessary...
			
			if (defined ($defaultName)){
				$fh .= $defaultName;
				$handleType = 'FILENAME'; # File handle has been changed to include file name
			} elsif (
				$defaultHandleType eq 'FILEHANDLE' ||
				$defaultHandleType eq 'FILENAME'
			){
				die "FILEHANDLE or FILENAME requested as output by subroutine but no file name (or default file name by subroutine) was provided, detected input file handle was of type $handleType, contents $fh\n";
			}
		}
		
		# Break up path into segments...
		my $folderSwitch;
		$folderSwitch = 0 if $handleType eq 'FOLDERHANDLE';
		my ($folder, $fileName, $extension) = folderFileNameSplit ($fh, $folderSwitch); #$folderSwitch = 0 makes path definitely
		
		$folder = directoryPathCleaner ($folder, 0);
		
		$$outputData{'folder'} = $folder;
		$$outputData{'fileName'} = $fileName;
		$$outputData{'extension'} = $extension;
		$$outputData{'fullPath'} = $folder.$fileName.$extension;
		$$outputData{'fullFileName'} = $fileName.$extension;
		
		
	}
	
	
	# Pass through handles if they match the default handle type...
	if ($handleType eq 'FILEHANDLE'){
		if ($defaultHandleType eq 'FILEHANDLE'){
			$$outputData{'fileHandle'} = $fh;
		} else {
			die "$handleType supplied but $defaultHandleType was requested, cannot convert file handle to anything else\n";
		}
	}
	if ($handleType eq 'FOLDERHANDLE'){
		if ($defaultHandleType eq 'FOLDERHANDLE'){
			$$outputData{'folderHandle'} = $fh;
		} else {
			die "$handleType supplied but $defaultHandleType was requested, cannot convert folder handle to anything else\n";
		}

	}

	# -> open file/folder handles if requested
	if (
			($handleType eq 'FOLDERNAME') ||
			($handleType eq 'FILENAME')
	){
		if ($defaultHandleType eq 'FILEHANDLE'){
			open(my $fileHandle, $mode{$fileInOut}, $$outputData{'fullPath'}) or die "Can't open file: $!";
			$$outputData{'fileHandle'} = $fileHandle;
		
		} elsif ($defaultHandleType eq 'FOLDERHANDLE'){
			opendir(my $folderHandle, $$outputData{'folder'}) || die "Can't opendir: $!";
			$$outputData{'folderHandle'} = $folderHandle;
		}
	}
	
	# -> Test handles to see if they will do what you want them to -> read/write/parse folders, etc...

	# Pass through handles if they match the default handle type...
	if ($defaultHandleType eq 'FILEHANDLE'){
		switch ($fileInOut){
			case 'READ'		{	# Read/write zero characters from handle as test...
								my $temp;
								if (!defined (read ($$outputData{'fileHandle'}, $temp, 0))){
									die "Cannot operate $fileInOut on file handle: $!";
								}
							} 
			case 'WRITE'		{
								unless (print {$$outputData{'fileHandle'}} ''){
									die "Cannot operate $fileInOut on file handle: $!";
								}
							}
			case 'APPEND'	{ 
								unless (print {$$outputData{'fileHandle'}} ''){
									die "Cannot operate $fileInOut on file handle: $!";
								}
							}
			else			{	die "fileInOut is not either IN, OUT or APPEND";	}
		}
	}
	
	
	if ($defaultHandleType eq 'FOLDERHANDLE'){
		# Get current index as folder test
		die "Cannot operate on folder handle: $!" unless defined telldir ($$outputData{'folderHandle'});
	}
	
	#### Possible to do...
	# Option to create directory tree if it doesn't exist!?
	# Option to die if file already exists to make sure data is not destroyed when writing!?
	# Multiple default names, aka, POSCAR, CONTCAR, etc...
	
	# Default file extension -> Could be useful
	# Process materials studio file formats -> *.xtd, *.xsd, etc...
	##MS data formats
	##-> direct reference to document
	##-> Name of document which already exists
	##-> Name for new document

	
	return $outputData;
}



1;


