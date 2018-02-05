# AtomisticFileConversion-PERL5

Perl modules for loading and saving crystallographic data in various formats including VASP 5.2.12, 5.3.5 and Materials Studio (6.0+)


Note: Loading and saving files in Materials Studio formats may uses the internal Materials Studio data structures accessed by the Perl API.

Therefore, a few import and export routines require the use of the Materials Studio program.



## Single crystal structure file formats:

- VASP POSCAR (IN, OUT)

- Materials Studio *.XSD  (IN, OUT)

- Materials Studio *.msi (OUT)

- VASP CHGCAR (IN, Single frame)


## Trajectory file formats:

- VASP file formats: 

- VASP XDATCAR (IN, OUT)

- VASP CHG (IN)

- Materials Studio *.XTD (OUT, does not support time step, is also slow)

- Materials Studio *.trj/MDTR (OUT, imports time step but does not support variable unit cell parameters very well)






## Grid file formats: 

- VESTA *.grd(eg VESTA) (OUT)

- Materials Studio .grd(MS6.0) (OUT)

- VASP CHGCAR (IN, Single frame)

- VASP CHG (IN, Trajectory)




## Simplest method for using this library: 

1.-Open a Materials Studio project

2.-Extract the files into the project

3.-Uncomment use lib 'C:\My\Path\To\Libraries';

4.-Edit use lib 'C:\My\Path\To\Libraries' to point to root folder containing the extracted AtomisticFileConversion and Math folders

5.-Uncomment the file lines you wish to use and edit the file names

6.-Run the script by pressing 'F5'


