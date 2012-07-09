#!/bin/bash

# alias csvgrep=/Users/wilson/local/bin/csvgrep
source /Users/wilson/.bash_profile

echo csvgrep tests
echo ----------------------------------------------------------------- 

echo 1. filter first column of a csv file
echo "> csvgrep '\$1' contacts.csv"
if csvgrep '$1' contacts.csv
then
	echo PASSED
else
	echo FAILED
fi
echo ----------------------------------------------------------------- 
echo 2. filter the column named with '*Name*'
echo "> csvgrep '@header \$NR == 1; \${Name}' contacts.csv"
if csvgrep '@header $NR == 1; ${Name}' contacts.csv
then
	echo PASSED
else
	echo FAILED
fi
echo ----------------------------------------------------------------- 
echo "3. The header must be declared, if don't it returns an error"
echo "> csvgrep '\${Name}' contacts.csv"
if csvgrep '${Name}' contacts.csv
then
	echo FAILED
else
	echo PASSED
fi
echo ----------------------------------------------------------------- 
echo "4. filter the column named *Name* based on column named *Email*"
echo "> csvgrep '@header \$NR == 1; \${Name} ; \${Email} eq /@www.com/' contacts.csv"
if csvgrep '@header $NR == 1; ${Name} ; ${Email} eq "@popstar.com"' contacts.csv
then
	echo PASSED
else
	echo FAILED
fi
echo -----------------------------------------------------------------
echo "6. filter the column named *Name* based on column named *Email* and "
echo "hide the email column"
echo "> csvgrep '@header \$NR == 1; \${Name} ; @hide \${Email} eq /@www.com/' contacts.csv"
if csvgrep '@header $NR == 1; ${Name} ; @hide ${Email} eq "@popstar.com"' contacts.csv
then
	echo PASSED
else
	echo FAILED
fi
echo

