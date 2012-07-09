#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Std;

package CSV;

sub parseCsvLine {
    my $row = shift;
    my $size = shift;
    my ($c, $s) = ('', '');

    if ($row =~ /"/) {
        my @fields = split /"/, $row;
        my $i = 0;
        for (@fields) {
            chomp;
            s/,/§/g if ($i++ % 2 == 0);
            $s .= $_;
        }
        $s =~ s/§$//;
        $c = '§';
    } else {
        $c = ',';
        $s = $row;
    }

    if ($size) {
        return split /$c/, $s, $size;
    } else {
        return split /$c/, $s;
    }
}

package Attribute;

use strict;
use warnings;

sub new {
	my $object = shift();
	my $class = ref( $object ) || $object;
	my $self = { _name => shift(), _value => shift() };

	bless( $self, $class );
	return $self;
}

sub name {
	my $self = shift();
	$self->{ _name } = shift if ( @_ );
	return $self->{ _name };
}

sub value {
	my $self = shift();
	$self->{ _value } = shift if ( @_ );
	my $value = $self->{_value};
	$value = $self->{_value} =~ m/,/ ? "\"$value\"" : $value;
	return $value;
}

package Attributes;

use strict;
use warnings;

sub new {
	my $object = shift();
	my $class = ref( $object ) || $object;
	my $self = { @_ };

	bless( $self, $class );
	return $self;
}

sub add {
	my $self = shift;
	my $attr = shift;
	$self->{$attr->name()} = $attr;
}

sub get {
	my $self = shift();
	return $self->{$_[0]};
}

package Position;

use strict;
use warnings;

sub new {
	my $self = shift();
	my $class = ref( $self ) || $self;
	
	$self = { _name => shift };
	$self->{attributes} = new Attributes;

	bless( $self, $class );
	return $self;
}

sub name {
	my $self = shift();
	$self->{_name} = shift if ( @_ );
	return $self->{_name};
}

sub template {
	my $self = shift();
	if ( $self->attribute("Template") ) {
		my $template = $self->attribute("Template")->value();
		if ( $template =~ /^VOT Portfolio$/ ) {
			return "ZZZ";
		} else {
			return $template;
		}
	} else {
		return '';
	}
}

sub id {
	my $self = shift();
	my $id = $self->attribute('POS/ID')->value();
	$id =~ s/<.*>//;
	return $id;
}

sub attribute {
	my $self = shift;
	my $attrName = shift;
	if ( @_ == 1 ) {
		my $attrValue = shift;
		if ( not $self->{attributes}->get($attrName) ) {
			if ( $attrValue =~ /\d{4}\/\d{2}\/\d{2} -?\d+\.\d+(?:, )?/ ) {
				my @rwDates = split /, /, $attrValue;
				foreach my $rwDate ( @rwDates ) {
					$rwDate =~ m/(\d{4}\/\d{2}\/\d{2}) (-?\d+\.\d+)/;
					my $attr = new Attribute("$attrName $1", $2);
					$self->{attributes}->add($attr);
				}
			} else {
				my $attr = new Attribute($attrName, $attrValue);
				$self->{attributes}->add($attr);
			}
		}
	} elsif ( @_ == 0 ) {
		return $self->{attributes}->get($attrName);
	}
}

sub merge {
	my $self = shift;
	my $position = shift;

	foreach my $attr ( values %{$position->{attributes}} ) {
		$self->attribute($attr->name(), $attr->value()) if not $self->attribute($attr->name());
	}
}

sub mergeOthers {
	my $self = shift;

	my $newPosition = new Position( $self->name() );
	foreach my $position ( @_ ) {
		foreach my $attr ( values %{$position->{attributes}} ) {
			$newPosition->attribute($attr->name(), $attr->value());
		}
	}

	return $newPosition;
}

sub print {
	my $self = shift();
	my @header = @_;
	return if ( not $self->attribute("StressTestReport") );

	my @attrValues = ();
	foreach ( @header ) {
		my $v = '';
		if ($self->attribute($_)) {
			$v = $self->attribute($_)->value();
		}
		push(@attrValues, $v);
	}
	print(join(',', @attrValues), "\n");
}

package StressTestReport;

use strict;
use warnings;

sub new {
	my $self = shift;
	my $class = ref( $self ) || $self;

	$self = { };
	$self->{dates} = { };
	$self->{title} = '';
	bless( $self, $class );

	return $self;
}

sub parse {
	my $self = shift;
	my $filename = shift;
	open( REPORT_FILE, $filename ) or die( "Problems reading file $filename - $!" );

	$self->{title} = <REPORT_FILE>; # first line = title line
	my $currentPosition = undef;
	my @attributeNames = ();

	while (<REPORT_FILE>) {
		chomp;
		next if /^$/;
		next if /^$/;
		next if /^Scenario:/;

		if (/^Position:/) {
			my @fields = split /:/;
			my $name = $fields[1];
			$name =~ s/,$//;
			$name =~ s/^\s+//;
			$currentPosition = new Position($name);
		} elsif (/^"/) {

			if (/^"\s+"/) {
				@attributeNames = CSV::parseCsvLine($_);
			} elsif (/^"(\d{4}\/\d{2}\/\d{2})"/) {
				my $date = $1;
				my @attributeValues = CSV::parseCsvLine($_);
				$#attributeValues == $#attributeNames || die "Names and Attributes must have size: " . $currentPosition->name();

				for (my $i=0 ; $i <= $#attributeValues ; $i++) {
					my $attrValue = '';
					my $attrName = $attributeNames[$i];
					$attrName =~ s/\s+//;
					if ($attrName =~ /^$/) {
						$attrName = 'Name';
						$attrValue = $currentPosition->name();
					} else {
						$attrName = $attributeNames[$i];
						$attrValue = $attributeValues[$i];
					}
					$currentPosition->attribute($attrName, $attrValue);
				}

				$currentPosition->attribute("StressTestReport", 1);
				$currentPosition->attribute("Report", "StressTestReport");

				if ( defined($self->{dates}->{$date}) ) {
					$self->{dates}->{$date}->{$currentPosition->id()} = $currentPosition;;
				} else {
					$self->{dates}->{$date} = { $currentPosition->id() => $currentPosition };
				}

			}
		}
	}

	close(REPORT_FILE);

	my @dates = sort keys %{$self->{dates}};
	$self->{firstDate} = $dates[0];
}

sub position {
	my $self = shift;
	my $date;
	if ( @_ == 2) {
		$date = shift;
	} else {
		$date = $self->{firstDate};
	}

	my $positionId = shift;
	return $self->{dates}->{$date}->{$positionId};
}

sub positions {
	my $self = shift;
	my $date = undef;

	if ( @_ == 1) {
		$date = shift;
	} else {
		$date = $self->{firstDate};
	}
	return values %{$self->{dates}->{$date}};
}

sub print {
	my $self = shift;

	foreach ( sort keys %{$self->{dates}} ) {
		print "Date: $_\n";
		foreach( @{ $self->{dates}->{ $_ } } ) { print $_ . "\n"; }
		print "\n\n";
	}
}

package Portfolio;

use strict;
use warnings;

sub new {
	my $object = shift;
	my $class = ref( $object ) || $object;
	my $self = {_name => shift, _id => undef, _positions => [ @_ ],
		_positions_dict => {}};

	bless( $self, $class );
	return $self;
}

sub name {
	my $self = shift();
	$self->{_name} = shift if ( @_ );
	return $self->{_name};
}

sub id {
	my $self = shift();
	$self->{_id} = shift if ( @_ );
	return $self->{_id};
}

sub position {
	my $self = shift;
	my $position = shift;
	if ($position =~ /^\d+$/) {
		my @positions = @{$self->{_positions}};
		return $positions[$position];
	} else {
		return $self->{_positions_dict}->{$position};
	}
}

sub add {
	my $self = shift;
	my $position = shift;

	push( @{$self->{_positions}}, $position );
	$self->{_positions_dict}->{$position->id()} = $position;
}

sub positions {
	my $self = shift;
	return @{$self->{_positions}};
}

sub print {
	my $self = shift;

	foreach my $position ( @{$self->{_positions}} ) {
		$position->print();
	}
}

package PortfolioReport;

use strict;
use warnings;

sub new {
	my $self = shift;
	my $class = ref( $self ) || $self;

	$self = { };
	$self->{_portfolios} = [ @_ ];
	$self->{_positions} = { };
	$self->{title} = '';
	bless( $self, $class );

	return $self;
}

sub portfolios {
	my $self = shift;
	return @{$self->{_portfolios}};
}

sub parse {
	my $self = shift;
	my $filename = shift;
	open( REPORT_FILE, $filename ) or die( "Problems reading file $filename - $!" );

	$self->{title} = <REPORT_FILE>; # first line = title line
	my $currentPortfolio = undef;
	my $currentPosition = undef;
	my @attributeNames = ();

	while (<REPORT_FILE>) {
		chomp;
		next if /^$/;
		next if /^$/;

		if (/^([^,]+),$/) { # PORTFOLIO NAME LINE
			push( @{$self->{_portfolios}}, $currentPortfolio ) if ($currentPortfolio);
			$currentPortfolio = new Portfolio($1);
			my $row = <REPORT_FILE>;
			@attributeNames = CSV::parseCsvLine($row);
			next;
		} else {
			my @attributeValues = CSV::parseCsvLine($_, scalar @attributeNames);
			my $name = $attributeValues[0];
			$currentPosition = new Position($name);

			$#attributeValues == $#attributeNames || die "Names and Attributes have different size: " . $currentPosition->name();
			for (my $i=0 ; $i <= $#attributeValues ; $i++) {
				my $attrName = $attributeNames[$i];
				$attrName =~ s/\s+//;
				next if $attrName =~ /^$/;
				my $attrValue = $attributeValues[$i];
				$currentPosition->attribute($attributeNames[$i], $attrValue);
			}
			$currentPosition->attribute("PortfolioReport", 1);
			$currentPosition->attribute("Report", "PortfolioReport");

			$currentPortfolio->add($currentPosition);
			$self->{_positions}->{$currentPosition->id()} = $currentPosition;
		}
	}

	close(REPORT_FILE);
}

sub position {
	my $self = shift;
	my $positionId = shift;
	return $self->{_positions}->{$positionId};
}

sub positions {
	my $self = shift;
	return values( %{$self->{_positions}} );
}

sub print {
	my $self = shift;

	foreach my $portfolio ( @{$self->{_portfolios}} ) {
		print "Portfolio: " . $portfolio->name() . "\n";
		foreach my $position ( $portfolio->positions() ) {
			print $position->id() . "\n";
		}
		print "\n\n";
	}
}

package Report;

use strict;
use warnings;

sub new {
	my $self = shift;
	my $class = ref( $self ) || $self;

	$self = { };
	bless( $self, $class );

	return $self;
}

sub merge {
	my $self = shift;
	my $reportTo = shift;
	my $reportFrom = shift;
	foreach my $position ( $reportTo->positions() ) {
		my $positionFrom = $reportFrom->position($position->id());
		$position->merge($positionFrom);
	}

	my @positions = $reportTo->positions();
	$self->{positions} = \@positions;
}

sub print {
	my $self = shift;

	my @header = keys(%{$self->{positions}->[0]->{attributes}});
	my $header = join(',', @header);
	print $header . "\n";

	my @sortedPositions = sort { $a->template() cmp $b->template() || $a->name() cmp $b->name() } @{$self->{positions}};
	foreach my $position ( @sortedPositions ) {
		$position->print( @header );
	}
}

package main;

my $reportPM = new PortfolioReport;
$reportPM->parse("Export_PM_BRASILIAII_PJUR2.csv");

my $reportST = new StressTestReport;
$reportST->parse("Export_BRASILIAII_PJUR2.csv");

my $report = new Report;
$report->merge( $reportST, $reportPM );
$report->print();

