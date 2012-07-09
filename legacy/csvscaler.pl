#!/usr/bin/env perl

my @headers = ();
my $totalFields = 0;
my %indexes = ();

while (<STDIN>) {
	next if (/^#/);
	print $_;
	@headers = parseCsvLine($_);
	last if ( @headers > 1 );
}

$totalFields = scalar @headers;

my @immune = ();
my $i = 0;
for (@headers) {
	chomp;
	$indexes{$_} = $i;
	if (/Sinal|Contract Size|Position Units|Valor Contabil Gerencial|Valor Presente Gerencial$/) {
		push(@immune, $i);
	}
	$i++;
}

my $contractSize_idx = $indexes{"Contract Size"};
my $positionUnits_idx = $indexes{"POS/Position Units"};

while (<STDIN>) {
	next if (/^#/);
	if (/VOT Portfolio/) { print $_; next; }
	my @fields = parseCsvLine($_);
	next if (scalar @fields != $totalFields);

	my $positionUnits = $fields[ $positionUnits_idx ];
	my $contractSize = $fields[ $contractSize_idx ];
	my $contractSize = $contractSize * 1 == 0 ? 1 : $contractSize;
	my $multiplier = $positionUnits * $contractSize;

	my @outFields = ();
	my $i = 0;
	for (@fields) {
		my $value;
		if (/^-?\d+\.\d+$/ and not isImmune($i) ) { # detect number fields
			$value = $_ * $multiplier;
			$value = sprintf("%.15f", $value);
		} else {
			if (/,/) {
				$value = "\"$_\"";
			} else {
				$value = $_;
			}
		}
		push(@outFields, $value);
		$i++;
	}
	print(join(',', @outFields), "\n");
}

sub isImmune {
	my $idx = shift;
	for (@immune) { return 1 if $idx == $_; }
	return 0;
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

