#!/usr/bin/perl

use strict;
use warnings;

my $db = {};
open(PJURPOS, 'pjur1pos');
while (<PJURPOS>) {
	chomp;
	my ($id, $position, $size, @thrash) = split /,/;
	$size = $size =~ m/^-?\d+\.\d+$/ ? $size : 1.0 ;
	if ( not defined($db->{$id}) ) {
		$db->{$id} = { position => $position, size => $size };
	} else {
		die "double position = $id";
	}
}
close(PJURPOS);

my $totalPositions = scalar keys(%$db);
print "Total positions = $totalPositions\n";

my $exposure = {};

open(PJUR, 'pjur1');
while (<PJUR>) {
	chomp;
	my ($id, @payments) = split /,/;
	for (@payments) {
		my ($date, $value);
		if (/(\d{4}.\d{2}.\d{2}) (-?\d+\.\d+)/) {
			$date = $1;
			$value = $2;
		} else {
			die "Date doesn't match: $_";
		}
		if ( defined($db->{$id}) ) {
			$db->{$id}->{$date} = $value;
			my $position = $db->{$id}->{position};
			my $size = $db->{$id}->{size};
			$exposure->{$date} += $value * $position * $size;
		}
	}
}
close(PJUR);

foreach (sort keys %$exposure) {
	printf "PJUR1 Exposure %10s = %20.6f\n", $_, $exposure->{$_};
}
