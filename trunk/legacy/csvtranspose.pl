#!/usr/bin/env perl
# vim: nocindent noai smartindent sw=4 ts=4
# csvtranspose
#
# Copyright 2008 Wilson Freitas
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, version 2.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You have received a copy of the GNU General Public License along
#   with this program, on the COPYING file.
#

use strict;
use Getopt::Std;

my $AUTHOR = "Wilson Freitas";
my $EMAIL = 'wilson.freitas@gmail.com';
my $ME = "csvtranspose";
my $URL = 'http://aboutwilson.net/csvtranspose';
my $VERSION = '0.1.0';

my $pattern = '.*';
our $opt_p;
getopt('p:');

if ( defined($opt_p) ) {
	$pattern = $opt_p;
}

my @columns = ();
my @values  = ();

while (<STDIN>) {
	next if /^$/;
	@columns = parseCsvLine($_) if /^[^,]/;

	if (/^,/ and /$pattern/) {
		@values = parseCsvLine($_);
		printNameValueColumns(\@columns, \@values);
		printSeparator();
	}
}

sub printSeparator {
	print('-' x 80, "\n");
}

sub buildFormatString {
	my @columns = @{ $_[0] };
	my @values  = @{ $_[1] };
    my $nameLength = 0;
    my $valueLength = 0;
	my $i = 0;
    foreach (@values) {
		$nameLength  = length( $columns[$i+1] ) if length($columns[$i+1]) > $nameLength;
		$valueLength = length( $values[$i] )    if length($values[$i])    > $valueLength;
		$i++;
    }
    $nameLength += 1;
    $valueLength += 1;

    return sprintf("%%3d. %%-%ds = %%-%ds\n", $nameLength, $valueLength);
}

sub printNameValueColumns {
	my @columns = @{ $_[0] };
	my @values  = @{ $_[1] };
	my $formatString = buildFormatString(\@columns, \@values);
	for (my $i = 0 ; $i<@values ; $i++) {
		printf $formatString, $i, $columns[$i], $values[$i];
	}
}

sub parseCsvLine {
	my $row = shift;
	my $separator = @_ == 1 ? shift : ',';
	$separator = '\|' if ($separator eq '|');

	my @fields = split /"/, $row;
	my ($i, $s) = (0, "");
	for (@fields) {
		chomp;
		s/$separator/§/g if ($i++ % 2 == 0);
		$s .= $_;
	}
	return split /§/, $s;
}
