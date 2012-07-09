#!/usr/bin/perl

use strict;
use warnings;

package Setup;

use Getopt::Std;

my $AUTHOR                 = "Wilson Freitas";
my $EMAIL                  = 'wilson.freitas@gmail.com';
my $ME                     = "cipo";
my $URL                    = 'http://aboutwilson.net/csvtools';
my $VERSION                = '0.1.0';
my $DEFAULT_SEPARATOR_TEXT = ',';
my $DEFAULT_SEPARATOR      = qr/$DEFAULT_SEPARATOR_TEXT/;
my $VERSION_MESSAGE        = "$ME $VERSION
Mantained by $AUTHOR <$EMAIL>
$URL

";



package CSVFile;




sub parse_line {
	my $row = shift;
	my $separator = @_ == 1 ? shift : $DEFAULT_SEPARATOR;

# $separator = '\|' if ($separator eq '|');

	my ($i, $s) = (0, "");
	my @fields = split /"/, $row;

	for (@fields) {
		chomp; s/^\s+//; s/\s+$//;
		s/$separator/§/g if ($i++ % 2 == 0);
		$s .= $_;
	}

	@fields = split /§/, $s, -1;
	for (@fields) {
		s/^\s+//; s/\s+$//;
	}

	return @fields;
}

