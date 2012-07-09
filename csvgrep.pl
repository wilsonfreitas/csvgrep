#!/usr/bin/env perl
# csvgrep - csv grep tool
#
# The MIT License
# 
# Copyright (c) 2008-2012 Wilson Freitas <wilson.freitas@gmail.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# 

use strict;
use warnings;

package Setup;

use Getopt::Std;

my $AUTHOR                 = "Wilson Freitas";
my $EMAIL                  = 'wilson.freitas@gmail.com';
my $ME                     = "csvgrep";
my $URL                    = 'http://aboutwilson.net/csvgrep/';
my $VERSION                = '1.0';
my $DEFAULT_SEPARATOR_TEXT = ',';
my $DEFAULT_SEPARATOR      = qr/$DEFAULT_SEPARATOR_TEXT/;
my $VERSION_MESSAGE        = "$ME $VERSION
Mantained by $AUTHOR
$URL

";
my $HELP_MESSAGE = "Usage: $ME [OPTIONS] CODE [FILE]

OPTIONS:
	-a	[print-all] prints all fields, except with \@hide
	-C	[check] checks whether the number of columns is constant
	-c	[close] puts one delimiter at the end of each output line
	-IS	[input-delimiter] sets the input delimiter
	-OS	[output-delimiter] sets the output delimiter
	-SS	[io-delimiter] sets input and output delimiters
	-f	[filename] prints input filename
	-N	[number] prints line numbers
	-p	[print-headers] prints headers
	-s	[headers-only] prints only headers
	-u	[unquote] unquote output fields
	-v	[verbose] verbose mode on
	-V	[version] prints csvgrep's version
	-h	[help] prints this message

---
Version $VERSION
Mantained by $AUTHOR
$URL
";

our %options = ();
our %arguments = ();

sub _getopt {
	my $result = getopts("acChI:lLfFnNO:psS:uvVw", \%options);
	$options{'help'} = exists $options{'h'};
	print_help() if not $result or $options{'help'};

	$options{'print-all'}        = exists $options{'a'};
	$options{'numbers'}          = exists $options{'N'};
	$options{'no-quote'}         = exists $options{'u'};
	$options{'close'}            = exists $options{'c'};
	$options{'check-columns'}    = exists $options{'C'};
	$options{'print-header'}     = exists $options{'p'};
    $options{'show-header'}      = exists $options{'s'};
	$options{'with-filename'}    = exists $options{'f'};
	$options{'without-filename'} = exists $options{'F'};

	$options{'with-header'} = exists $options{'w'};
	$options{'with-header'} = 1 if $options{'show-header'} or $options{'print-header'} or $options{'check-columns'};

	$options{'verbose'} = exists $options{'v'};
	$options{'verbose'} = 1 if $options{'check-columns'};

#
# process separators
#
	$options{'separator'} = exists $options{'S'} ? $options{'S'} : '';
	if ($options{'separator'}) {
		$options{'input-separator'}  = qr/$options{'separator'}/;
		$options{'output-separator'} = $options{'separator'};
	} else {
		# if (exists $options{'I'}) {
		# 	my $separator = '\|' if ($options{'I'} eq '|');
		# 	$options{'input-separator'}  = qr/$separator/;
		# } else {
		# 	$options{'input-separator'}  = $DEFAULT_SEPARATOR;
		# }
		$options{'input-separator'} = exists $options{'I'} ? qr/$options{'I'}/ : $DEFAULT_SEPARATOR;
		$options{'output-separator'} = exists $options{'O'} ? $options{'O'} : $DEFAULT_SEPARATOR_TEXT;
	}

#
# process the input file
#
# if (not ($options{'show-header'} or $options{'check-columns'})) {
# 	$arguments{'code'} = shift @ARGV;
# }
	$arguments{'code'} = shift @ARGV;

	if (@ARGV) {
		$arguments{'input-file-names'} = [];

		for (@ARGV) {
			push(@{$arguments{'input-file-names'}}, $_);
		}

		$options{'without-filename'} = 1 if @{$arguments{'input-file-names'}} == 1 and not $options{'with-filename'};
	}
}

sub print_help {
	print $HELP_MESSAGE;
	exit 1;
}

sub print_version {
	print $VERSION_MESSAGE;
	exit 0;
}


package Error;

sub warn_message {
	my $message = shift;

	warn "Warning: $message\n" if $Setup::options{'verbose'};
}

sub error_message {
	my $message = shift;

	warn "Error: $message";
}

sub fatal_message {
	my $message = shift;
	my $code = shift;

	warn "Fatal: $message";

	exit $code;
}

sub syntax_message {
	my $message = shift;
	my $code = shift;

	warn "Syntax Error: $message";

	exit $code;
}

package CSVFile;

my $line_details = {'header-row' => undef,
	'header-line' => '',
	'current-row' => undef,
	'current-line' => '', 
	'first-row' => undef,
	'matched' => 1,
	'header-matched' => 1,
	'line-number' => 0};

our $check_failed = 0;

our $filename = '';

sub show_header {
#
# process show-header option
#

	my $f = ($filename and not $Setup::options{'without-filename'}) ? "${filename}:" : '';

	my $i = 1;

	my @c = map { sprintf "%d,%s", $i++, $_ } @{$line_details->{'header-row'}};

	my $j = join(';', @c);

	printf "%sLine %d:%s\n", $f, $., $j;
}

sub print_header {
#
# process output header -- make it printable
#

	my @printable_header = ();
	my @header = @{$line_details->{'header-row'}};

	if ($options{'print-all'}) {

		for (my $i=0 ; $i < @header ; $i++) {
			my $printable = is_printable_for_all($i);
			my $h = FIO::printable_field($header[$i]);
			push(@printable_header, $h) if $printable;
		}

	} else {

		for (@Parser::rules) {
			my $h;
			if (defined $_->{'column-index'}) {
				$h = FIO::printable_field($header[$_->{'column-index'}]);
			} elsif (defined $_->{'special-variable'}) {
				$h = $_->{'special-variable'};
			}
			push(@printable_header, $h) if not $_->{'hide'};
		}

	}

	FIO::print_columns(@printable_header);
}

sub is_printable_for_all {
	my $id = shift;

	my $idx;

	for (my $i = 0 ; $i < @Parser::rules ; $i++) {
		my $rule = $Parser::rules[$i];
		my $index = $rule->{'column-index'};

		if (defined $index and $index == $id) {
			$idx = $i;
			last;
		}
	}

	my $hidden = (defined $idx and $Parser::rules[$idx]->{'hide'});

	return ((not defined $idx) or (not $hidden));
}

sub match_index {
	my $field = shift;
	# my $field_pattern = qr/$field/;
	my @header = @{$line_details->{'header-row'}};

    if (ref \$field eq 'SCALAR') {
		for (my $i=0 ; $i < @header ; $i++) {
    		return $i if $header[$i] eq $field;
    	}
    } elsif (ref $field eq 'ARRAY') {
        my @indexes = ();
	    for (my $j=0 ; $j < @{$field} ; $j++) {
	        if ($field->[$j] =~ m/\d+/) {
	            push(@indexes, $field->[$j]);
	            next;
	        }
        	for (my $i=0 ; $i < @header ; $i++) {
        		push(@indexes, $i) if $header[$i] eq $field->[$j];
    	    }
    	}
    }

# Error::fatal_message("\"$field\" does't match any column name", 3);
	return undef;
}

sub reset_line_details {
	$line_details->{'header-row'} = undef;
	$line_details->{'header-line'} = '';
	$line_details->{'current-row'} = undef;
	$line_details->{'current-line'} = '';
	$line_details->{'first-row'} = undef;
	$line_details->{'matched'} = 1;
	$line_details->{'header-matched'} = 1;
	$line_details->{'line-number'} = 0;
}

#
# process lines
#
sub process_file {
	no strict 'refs';

    # reset line details
	reset_line_details();

	my $file_handler = 'STDIN';
	if (@_ == 1) {
		$file_handler = 'INPUT_FILE';
		$filename = shift;
		open($file_handler, $filename) or Error::warn_message("Error while opening $filename.");
	}

	while (<$file_handler>) {
		chomp;
		s/\s+$//;     # remove remaining \r chars
		next if /^#/; # ignore comments
		next if /^$/; # ignore empty lines

		my @current_row = FIO::parse_csv_line($_, $Setup::options{'input-separator'});
		$line_details->{'current-line'} = $_;
		$line_details->{'current-row'} = \@current_row;
		$line_details->{'matched'} = 1;
		$line_details->{'header-matched'} = 1;
		$line_details->{'line-number'} = $.;

        # process header
		if ($Setup::options{'with-header'}) {
			my $processing_header = 0;

            # process headers
			if (@Parser::header_rules) {
				for (@Parser::header_rules) {
					my $lhs = $_->{'lhs-resolver'}->($_, $line_details);

					if (not $_->{'operator'}->($lhs, $_->{'expr'})) {
						$line_details->{'header-matched'} = 0;
						last;
					}
				}
			} else {
                # $line_details->{'header-matched'} = 0 if $line_details->{'line-number'} > 1;
				Error::fatal_message('The @header field must be defined', 7);
			}

			if ($line_details->{'header-matched'}) {
				$line_details->{'header-row'} = $line_details->{'current-row'};
				$line_details->{'header-line'} = $line_details->{'current-line'};
				for (@Parser::rules) {
					# print $_->{'column-name'} . " " . CSVFile::match_index($_->{'column-name'}) . "\n";
					if (defined $_->{'column-name'}) {
						$_->{'column-index'} = CSVFile::match_index($_->{'column-name'});
					}
				}
				$processing_header = 1;
			}

			next if not defined $line_details->{'header-row'};

			if ($Setup::options{'show-header'}) {
				show_header() if $processing_header;
				next;
			}

			if ($Setup::options{'print-header'} and $processing_header) {
				print_header();
				next;
			}

			if (@{$line_details->{'current-row'}} != @{$line_details->{'header-row'}}) {
                # Error::warn_message("header's columns = "    . @{$line_details->{'header-row'}}  .
                #       ", line $.'s columns = " . @{$line_details->{'current-row'}} . ".");
				$check_failed = 1 if $Setup::options{'check-columns'};
			}
			
			# TODO: the -c option, close, must close the header lines

			next if $Setup::options{'check-columns'}; 
			next if $processing_header; 
		}

        # process lines
		my @out_fields = ();
		for (@Parser::rules) {
			my $lhs = $_->{'lhs-resolver'}->($_, $line_details);
			
			if ($_->{'operator'}->($lhs, $_->{'expr'})) {
				my $h = FIO::printable_field($lhs);
				push(@out_fields, $h) if not $_->{'hide'};
			} else {
				$line_details->{'matched'} = 0;
				last;
			}
		}

		if ($line_details->{'matched'}) {
			if ($Setup::options{'print-all'}) {
				@out_fields = ();

				for (my $i=0 ; $i < @{$line_details->{'current-row'}} ; $i++) {
					my $printable = is_printable_for_all($i);

					my $h = FIO::printable_field($line_details->{'current-row'}->[$i]);

					push(@out_fields, $h) if $printable;
				}
			}

			FIO::print_columns(@out_fields);
		}
	}

	close($file_handler);
}


package Parser;

#
# process parameters (rules)
#

our @rules = ();
our @header_rules = ();

my %functions = (
	'du' => \&Operators::dummy,
	'bo' => \&Operators::bool_evaluation_operator,
	'in' => Operators::string_operator(\&Operators::in),
	'eq' => Operators::string_operator(\&Operators::match),
	'ne' => Operators::string_operator(\&Operators::not_match),
	'==' => Operators::math_operator(\&Operators::equal_to), 
	'!=' => Operators::math_operator(\&Operators::not_equal_to), 
	'>'  => Operators::math_operator(\&Operators::greater_than), 
	'>=' => Operators::math_operator(\&Operators::greater_than_or_equal_to),
	'<'  => Operators::math_operator(\&Operators::less_than), 
	'<=' => Operators::math_operator(\&Operators::less_than_or_equal_to)
);

sub row_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	my $index = $rule->{'column-index'};

	return $line_details->{'current-row'}->[$index] if defined $index and defined $line_details->{'current-row'}->[$index];
}

sub length_row_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	my $index = $rule->{'column-index'};

	my $lhs = $line_details->{'current-row'}->[$index] if defined $index and 
		defined $line_details->{'current-row'}->[$index];

	return length($lhs);
}

sub line_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	return $line_details->{'current-line'};
}

sub length_line_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	return length($line_details->{'current-line'});
}

sub header_row_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	my $index = $rule->{'column-index'};

	return $line_details->{'header-row'}->[$index] if defined $index and defined $line_details->{'header-row'}->[$index];
}

sub length_header_row_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	my $index = $rule->{'column-index'};

	my $lhs = $line_details->{'header-row'}->[$index] if defined $index and defined $line_details->{'header-row'}->[$index];
	return length($lhs);
}

sub header_line_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	return $line_details->{'header-line'};
}

sub length_header_line_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	return length($line_details->{'header-line'});
}

sub NF_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	return (scalar @{$line_details->{'current-row'}});
}

sub NR_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	return $line_details->{'line-number'};
}

sub last_column_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	my $NF = scalar @{$line_details->{'current-row'}} - 1;
	return $line_details->{'current-row'}->[$NF];
}

sub CRS_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

    # my $begin, $end = split(//, $rule->{});
	return undef;
}

sub bool_lhs_resolver {
	my $rule = shift;
	my $line_details = shift;

	my $index = $rule->{'column-index'};

	my $ret = $line_details->{'current-row'}->[$index] if defined $index and defined $line_details->{'current-row'}->[$index];

	return lc($ret);
}

sub name_parser {
	my $chunk = shift;
	my $ignore = @_ ? shift : 2;

	my @a = split(//, $chunk);
	my @ref = ();
	my $i = $ignore; # ignoring first 2 chars
	for ( ; $i <= $#a ; $i++) {
		if ($a[$i] eq '\\') {
			$i++;
			if ($a[$i] eq '}' or $a[$i] eq '{' or $a[$i] eq '\\' or $a[$i] eq ',' or $a[$i] eq ':') {
				push(@ref, $a[$i]);
			} else {
				push(@ref, $a[--$i]);
				push(@ref, $a[++$i]);
			}
			next;
		}
		
		if ($a[$i] eq '$' and $a[$i+1] eq 'N' and $a[$i+2] eq 'F') {
		    push(@ref, '#NF#');
		    $i++; $i++; $i++;
		}

		if ($a[$i] eq ',') {
			push(@ref, '#CSS#');
		}

		if ($a[$i] eq ':') {
			push(@ref, '#CRS#');
		}

		if ($a[$i] eq '}') {
			$i++;
			last;
		}

		push(@ref, $a[$i]);
	}

	my $ref = join('', @ref);

	return ($i, $ref);
}

sub create_rule {
	return {
		'column-index' => undef,
		'column-name' => undef,
		'operator' => $functions{'du'},
		'expr' => undef,
		'lhs-resolver' => undef,
		'special-variable' => undef
	};
}

sub parse_rules {
	my $offset = 0;
	my $chunk = "";
	my $rule = create_rule();

	while (length($chunk = substr($Setup::arguments{'code'}, $offset))) {
		if ($chunk =~ /^(\s+)/) {
			$offset += length $1;
		} elsif ($chunk =~ /^(@[a-zA-Z_][a-zA-Z_0-9-]+)/) {
			$offset += length $1;
			$rule->{substr($1, 1)} = 1;
		} elsif ($chunk =~ /^(\$\*\{.*\})/) {
			$offset += length $1;
			print "PATTERN_REFERENCE: $1\n";
		} elsif ($chunk =~ /^(\$\?\d+)/) {
			$offset += length $1;
			my $i = substr($1, 2) + 0;
			$rule->{'column-index'} = $i-1;
			if ($i == 0) {
				$rule->{'lhs-resolver'} = \&line_lhs_resolver;
			} else {
				$rule->{'lhs-resolver'} = \&row_lhs_resolver;
			}
			$rule->{'operator'} = $functions{'bo'};
		} elsif ($chunk =~ /^\$\?\{/) {
			my ($i, $ref) = name_parser($chunk, 3);
			$offset += $i;
			$rule->{'column-name'} = $ref;
			$rule->{'lhs-resolver'} = \&row_lhs_resolver;
			$rule->{'operator'} = $functions{'bo'};
			$Setup::options{'with-header'} = 1;
		} elsif ($chunk =~ /^(\$\#\d+)/) {
			$offset += length $1;
			my $i = substr($1, 2) + 0;
			$rule->{'column-index'} = $i-1;
			if ($i == 0) {
				$rule->{'lhs-resolver'} = \&length_line_lhs_resolver;
			} else {
				$rule->{'lhs-resolver'} = \&length_row_lhs_resolver;
			}
		} elsif ($chunk =~ /^(\$\d+)/) {
			$offset += length $1;
			my $i = substr($1, 1) + 0;
			$rule->{'column-index'} = $i-1;
			if ($i == 0) {
				$rule->{'lhs-resolver'} = \&line_lhs_resolver;
			} else {
				$rule->{'lhs-resolver'} = \&row_lhs_resolver;
			}
		} elsif ($chunk =~ /^(\$(NR|NF))/) {
			$offset += length $1;
			my $i = substr($1, 1);
			$rule->{'special-variable'} = $i;
			if ($i eq 'NF') {
				$rule->{'lhs-resolver'} = \&NF_lhs_resolver;
			} elsif ($i eq 'NR') {
				$rule->{'lhs-resolver'} = \&NR_lhs_resolver;
			}
		} elsif ($chunk =~ /^\$\#\{/) {
			my ($i, $ref) = name_parser($chunk, 3);
			$offset += $i;
			$rule->{'column-name'} = $ref;
			$rule->{'lhs-resolver'} = \&length_row_lhs_resolver;
			$Setup::options{'with-header'} = 1;
		} elsif ($chunk =~ /^\$\{/) {
			my ($i, $ref) = name_parser($chunk);
			$offset += $i;
			if ($ref =~ m/#CSS#/ and $ref =~ m/#CRS#/) {
    			Error::syntax_message("Error on range definition", 1);
			} elsif ($ref =~ m/#CRS#/) {
			    $ref =~ s/(^\s+|\s+$)//;
			    my @parts = split /#CRS#/, $ref;
    			Error::syntax_message("Error on range definition", 1) if @parts != 2;
				$rule->{'column-name'} = \@parts;
				$rule->{'lhs-resolver'} = \&CRS_lhs_resolver;
    			$Setup::options{'with-header'} = 0;
			} elsif ($ref =~ m/#CSS#/) {
                # $rule->{'column-name'} = undef;
                # $rule->{'lhs-resolver'} = \&CSS_lhs_resolver;
			} elsif ($ref =~ m/^#NF#$/) {
				$rule->{'column-name'} = undef;
				$rule->{'lhs-resolver'} = \&last_column_lhs_resolver;
    			$Setup::options{'with-header'} = 0;
			} elsif ($ref =~ m/^\d+$/) {
				$rule->{'column-index'} = $ref - 1;
				$rule->{'lhs-resolver'} = \&row_lhs_resolver;
    			$Setup::options{'with-header'} = 0;
			} else {
				$rule->{'column-name'} = $ref;
				$rule->{'lhs-resolver'} = \&row_lhs_resolver;
    			$Setup::options{'with-header'} = 1;
			}
		} elsif ($chunk =~ /^(\$\$\#\d+)/) {
			$offset += length $1;
			my $i = substr($1, 3) + 0;
			$rule->{'column-index'} = $i-1;
			if ($i == 0) {
				$rule->{'lhs-resolver'} = \&length_header_line_lhs_resolver;
			} else {
				$rule->{'lhs-resolver'} = \&length_header_row_lhs_resolver;
			}
			$Setup::options{'with-header'} = 1;
		} elsif ($chunk =~ /^(\$\$\d+)/) {
			$offset += length $1;
			my $i = substr($1, 2) + 0;
			$rule->{'column-index'} = $i-1;
			if ($i == 0) {
				$rule->{'lhs-resolver'} = \&header_line_lhs_resolver;
			} else {
				$rule->{'lhs-resolver'} = \&header_row_lhs_resolver;
			}
			$Setup::options{'with-header'} = 1;
		} elsif ($chunk =~ /^(==|!=|>=|<=|>|<|eq|ne|le|ge|lt|gt|in)/) {
			$offset += length $1;
			$rule->{'operator'} = $functions{$1};
		} elsif ($chunk =~ /^\//) {
			Error::syntax_message("Expression already set", 5) if defined $rule->{'expr'};
			my @a = split(//, $chunk);
			my @ref = ();
			my $i = 1; # ignoring first char
			for ( ; $i <= $#a ; $i++) {
				if ($a[$i] eq '\\') {
					$i++;
					if ($a[$i] eq '/' or $a[$i] eq '\\') {
						push(@ref, $a[$i]);
					} else {
						push(@ref, $a[--$i]);
						push(@ref, $a[++$i]);
					}
					next;
				}
				
				if ($a[$i] eq '/') {
					$i++;
					last;
				}
				
				push(@ref, $a[$i]);
			}
			
			$offset += $i;
			$rule->{'expr'} = join('', @ref);
		} elsif ($chunk =~ /^(\"([^\\"]|(\\.))*\")/) {
			Error::syntax_message("Expression already set", 5) if defined $rule->{'expr'};
			$offset += length $1;
			my $text = $1;
			$text =~ s/\\"/"/g;
			$text =~ s/(^"|"$)//g;
			$rule->{'expr'} = $text;
		} elsif ($chunk =~ /^(\`([^\\"]|(\\.))*\`)/) {
			Error::syntax_message("Expression already set", 5) if defined $rule->{'expr'};
			$offset += length $1;
			my $cmd = $1;
			$cmd =~ s/\\`/`/g;
			my $output = eval $cmd;
			$rule->{'expr'} = $output;
		} elsif ($chunk =~ /^(-?(\d+\.\d+|\d+|\d+\.))/) {
			$offset += length $1;
			$rule->{'expr'} = $1;
		} elsif ($chunk =~ /^;/) {
			$offset += 1;
			if ($rule->{'header'}) {
				push(@header_rules, $rule);
			} else {
				push(@rules, $rule);
			}
			$rule->{'pushed'} = 1;
			$rule = create_rule();
		} else {
			Error::syntax_message("Unknown syntax [$chunk]", 5);
		}
	}

	if (not $rule->{'pushed'}) {
		if ($rule->{'header'}) {
			push(@header_rules, $rule);
		} else {
			push(@rules, $rule);
		}
	}
	
	if (@rules == 1 and not defined $rules[0]->{'lhs-resolver'}) {
		$rules[0]->{'lhs-resolver'} = $functions{'du'};
		$rules[0]->{'operator'} = $functions{'du'};
		# @rules->[0]->{''} = $functions{'du'};
	}
}

package FIO;

sub printable_field {
	my $field = shift;

	$field = "" if not defined $field;

	return $Setup::options{'no-quote'} ? $field : quote_if_necessary($field);
}

sub print_columns {
	my @out_fields = @_;

	my $output = "";

	$output .= "$CSVFile::filename:" if $CSVFile::filename and not $Setup::options{'without-filename'};

	$output .= "$.:" if $Setup::options{'numbers'};

	$output .= join($Setup::options{'output-separator'}, @out_fields);

	$output .= $Setup::options{'close'} ? $Setup::options{'output-separator'} : '';

	$output .= "\n";

	print $output if @out_fields;
}

sub quote_if_necessary {
	my $f = shift;

	my $output_separator = qr/$Setup::options{'output-separator'}/;

	$f = "\"$f\"" if ($f =~ /$output_separator/);

	return $f;
}

sub parse_csv_line {
	my $row = shift;
	my $separator = @_ == 1 ? shift : $DEFAULT_SEPARATOR;

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

package Operators;

sub dummy {
	return 1;
}

sub bool_evaluation_operator {
	use Regexp::Common;
	
	my $val = shift;
	
	if ($val =~ /^$/ or lc($val) =~ /^false$/) {
		return 0;
	} elsif ($val =~ m{^$RE{num}{real}$}) { # decimal number regex: /^-?(?:\d+(?:\.\d*)?|\.\d+)$/
		return 0 if $val == 0;
		return 1;
	} else {
		return 1;
	}
}

sub math_operator {
	my $operator = shift;

	return sub {
		use Regexp::Common;
		my ($lhs, $rhs) = @_;

		if ($lhs !~ m{^$RE{num}{real}$}) {
			$lhs = 0;
		}
		if ($rhs !~ m{^$RE{num}{real}$}) {
			$rhs = 0;
		}

		# no warnings;
		# eval {
		# 	$lhs + 0;
		# };
		# if ($@) {
		# 	$lhs = 0;
		# }
		# 
		# eval {
		# 	$rhs + 0;
		# };
		# if ($@) {
		# 	$rhs = 0;
		# }
		# $lhs = 0 if not defined $lhs or $lhs !~ /-?\d+(\.\d+)?/;
		# $rhs = 0 if not defined $rhs or $rhs !~ /-?\d+(\.\d+)?/;

		return $operator->($lhs, $rhs);
	};
}

sub string_operator {
	my $operator = shift;

	return sub {
		my ($lhs, $rhs) = @_;

		$lhs = "" if not defined $lhs;
		$rhs = "" if not defined $rhs;

		return $operator->($lhs, $rhs);
	};
}

sub in {
	my ($lhs, $rhs) = @_;

	return 0 if $lhs =~ /^$/;

	return index($rhs, $lhs) > -1;
}

sub match {
	my ($lhs, $rhs) = @_;

	$rhs = qr/$rhs/;

	return $lhs =~ /$rhs/;
}

sub not_match {
	my ($lhs, $rhs) = @_;

	$rhs = qr/$rhs/;

	return not $lhs =~ /$rhs/;
}

sub equal_to {
	my ($lhs, $rhs) = @_;

	return $lhs == $rhs;
}

sub not_equal_to {
	my ($lhs, $rhs) = @_;

	return $lhs != $rhs;
}

sub greater_than {
	my ($lhs, $rhs) = @_;

	return $lhs > $rhs;
}

sub greater_than_or_equal_to {
	my ($lhs, $rhs) = @_;

	return $lhs >= $rhs;
}

sub less_than {
	my ($lhs, $rhs) = @_;

	return $lhs < $rhs;
}

sub less_than_or_equal_to {
	my ($lhs, $rhs) = @_;

	return $lhs <= $rhs;
}

package main;

Setup::_getopt();

if ($Setup::options{'version'}) {
	Setup::print_version();
}

# if (not (defined $options{'show-header'} or defined $options{'check-columns'})) {
if (defined $Setup::arguments{'code'}) {
	Parser::parse_rules();
}

if (defined $Setup::arguments{'input-file-names'}) {
	for (@{$Setup::arguments{'input-file-names'}}) {
		CSVFile::process_file($_);
	}
} else {
	CSVFile::process_file();
}

if ($Setup::options{'check-columns'} and $CSVFile::check_failed) {
	exit 2;
}

