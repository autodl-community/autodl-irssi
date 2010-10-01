# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
# The Original Code is IRC Auto Downloader
#
# The Initial Developer of the Original Code is
# David Nilsson.
# Portions created by the Initial Developer are Copyright (C) 2010
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****

#
# Parses and creates rencoded strings.
#

use 5.008;
use strict;
use warnings;

my $SMALL_POSITIVE_INT_LO	= 0x00;	# Integers 0..43
my $SMALL_POSITIVE_INT_HI	= 0x2B;
my $FLOAT64					= 0x2C;
# 0x2D, 0x2E, 0x2F = ???
# 0x30-0x39 = INTEGER:STRING
# 0x3A = ???
my $LIST					= 0x3B;	# Variable length list
my $DICTIONARY				= 0x3C;	# Variable length dictionary
my $INTEGER					= 0x3D;	# Variable length integer
my $INTEGER1				= 0x3E;	# 1-byte signed integer
my $INTEGER2				= 0x3F;	# 2-byte signed integer
my $INTEGER4				= 0x40;	# 4-byte signed integer
my $INTEGER8				= 0x41;	# 8-byte signed integer
my $FLOAT32					= 0x42;
my $TRUE					= 0x43;
my $FALSE					= 0x44;
my $NULL					= 0x45;
my $SMALL_NEGATIVE_INT_LO	= 0x46;	# Integers -1..-32
my $SMALL_NEGATIVE_INT_HI	= 0x65;
my $SMALL_DICTIONARY_LO		= 0x66;	# Dictionary with 0..24 elements
my $SMALL_DICTIONARY_HI		= 0x7E;
my $TERMINATOR				= 0x7F;	# Terminates LIST, DICTIONARY, INTEGER, STRING
my $SHORT_STRING_LO			= 0x80;	# Short strings of length 0..63
my $SHORT_STRING_HI			= 0xBF;
my $SMALL_LIST_LO			= 0xC0;	# List with 0..63 elements
my $SMALL_LIST_HI			= 0xFF;

package AutodlIrssi::Rencoding::Base;

sub new {
	my ($class, $value) = @_;
	my $self = bless {}, $class;
	$self->{value} = $value if defined $value;
	return $self;
}

package AutodlIrssi::Rencoding::Integer;
use base qw/ AutodlIrssi::Rencoding::Base /;

sub encode {
	my $self = shift;

	my $val = $self->{value};
	die "Value not initialized\n" unless defined $val;
	die "Not an integer\n" unless $val =~ /^-?\d+$/;

	use bytes;
	if (0 <= $val && $val <= $SMALL_POSITIVE_INT_HI - $SMALL_POSITIVE_INT_LO) {
		return chr($SMALL_POSITIVE_INT_LO + $val);
	}
	elsif (-($SMALL_NEGATIVE_INT_HI - $SMALL_NEGATIVE_INT_LO + 1) <= $val && $val <= -1) {
		return chr($SMALL_NEGATIVE_INT_LO + -($val + 1));
	}
	elsif (-0x80 <= $val && $val <= 0x7F) {
		return chr($INTEGER1) . pack("c", $val);
	}
	elsif (-0x8000 <= $val && $val <= 0x7FFF) {
		return chr($INTEGER2) . pack("s>", $val);
	}
	elsif (-0x80000000 <= $val && $val <= 0x7FFFFFFF) {
		return chr($INTEGER4) . pack("l>", $val);
	}
	else {
		return chr($INTEGER) . $val . chr($TERMINATOR);
	}
}

package AutodlIrssi::Rencoding::FloatingPoint;
use base qw/ AutodlIrssi::Rencoding::Base /;

sub encode {
	my $self = shift;

	my $val = $self->{value};
	die "Value not initialized\n" unless defined $val;

	use bytes;
	return chr($FLOAT64) . pack("d>", $val);
}

package AutodlIrssi::Rencoding::String;
use base qw/ AutodlIrssi::Rencoding::Base /;
use Encode qw//;

sub encode {
	my $self = shift;

	my $val = $self->{value};
	die "Value not initialized\n" unless defined $val;

	use bytes;
	my $octets = Encode::encode("utf-8", $val);
	my $len = length($octets);
	if ($len <= $SHORT_STRING_HI - $SHORT_STRING_LO) {
		return chr($SHORT_STRING_LO + $len) . $octets;
	}
	else {
		return "$len:$octets";
	}
}

package AutodlIrssi::Rencoding::Boolean;
use base qw/ AutodlIrssi::Rencoding::Base /;

sub encode {
	my $self = shift;

	my $val = $self->{value};
	die "Value not initialized\n" unless defined $val;

	use bytes;
	return $val ? chr($TRUE) : chr($FALSE);
}

package AutodlIrssi::Rencoding::Null;
use base qw/ AutodlIrssi::Rencoding::Base /;

sub encode {
	my $self = shift;

	use bytes;
	return chr($NULL);
}

package AutodlIrssi::Rencoding::List;
use base qw/ AutodlIrssi::Rencoding::Base /;

sub new {
	my $self = shift->SUPER::new();
	$self->{list} = [];
	return $self;
}

# $value is another Rencoding::Base type
sub add {
	my ($self, $value) = @_;
	push @{$self->{list}}, $value;
}

sub encode {
	my $self = shift;

	use bytes;
	my $rv = "";

	my $numElems = @{$self->{list}};
	my ($start, $end);
	if ($numElems <= $SMALL_LIST_HI - $SMALL_LIST_LO) {
		$start = chr($SMALL_LIST_LO + $numElems);
	}
	else {
		$start = chr($LIST);
		$end = chr($TERMINATOR);
	}

	$rv .= $start;
	for my $type (@{$self->{list}}) {
		$rv .= $type->encode();
	}
	$rv .= $end if defined $end;
	return $rv;
}

package AutodlIrssi::Rencoding::Dictionary;
use base qw/ AutodlIrssi::Rencoding::Base /;

sub new {
	my $self = shift->SUPER::new();
	$self->{dict} = {};
	return $self;
}

# $value is another Rencoding::Base type
sub add {
	my ($self, $key, $value) = @_;
	$self->{dict}{$key} = $value;
}

sub encode {
	my $self = shift;

	use bytes;
	my $rv = "";

	my $numElems = keys %{$self->{dict}};
	my ($start, $end);
	if ($numElems <= $SMALL_DICTIONARY_HI - $SMALL_DICTIONARY_LO) {
		$start = chr($SMALL_DICTIONARY_LO + $numElems);
	}
	else {
		$start = chr($DICTIONARY);
		$end = chr($TERMINATOR);
	}

	$rv .= $start;
	while (my ($key, $type) = each %{$self->{dict}}) {
		my $stringType = new AutodlIrssi::Rencoding::String($key);
		$rv .= $stringType->encode();
		$rv .= $type->encode();
	}
	$rv .= $end if defined $end;
	return $rv;
}

package AutodlIrssi::Rencoding;
use base qw/ Exporter /;
our @EXPORT = qw/ parseRencodedString /;
our @EXPORT_OK = qw//;

my $parseTable = [];

use constant MAX_RECURSION => 100;

# Parses a rencoded string, returning a reference to a list of all parsed elements, or undef if an
# error was found.
sub parseRencodedString {
	my $s = shift;

	my @rv;
	my $info = {
		s => $s,
		start => 0,
		end => length $s,
	};
	eval {
		while (1) {
			$info->{level} = 0;
			push @rv, scalar _parseRencodedStringInternal($info);
			last if $info->{start} >= $info->{end};
		}
	};
	return if $@;
	return \@rv;
}

sub _initialize {
	_initializeParseTable();
}

sub _initializeParseTable {
	my $setRange = sub {
		my ($lo, $hi, $val) = @_;
		for my $i ($lo..$hi) {
			$parseTable->[$i] = $val;
		}
	};
	$setRange->($SMALL_POSITIVE_INT_LO, $SMALL_POSITIVE_INT_HI, \&_parseSmallPositiveInteger);
	$parseTable->[$FLOAT64] = \&_parseFloat64;
	$setRange->(0x30, 0x39, \&_parseString);
	$parseTable->[$LIST] = \&_parseList;
	$parseTable->[$DICTIONARY] = \&_parseDictionary;
	$parseTable->[$INTEGER] = \&_parseInteger;
	$parseTable->[$INTEGER1] = \&_parseInteger1;
	$parseTable->[$INTEGER2] = \&_parseInteger2;
	$parseTable->[$INTEGER4] = \&_parseInteger4;
	$parseTable->[$INTEGER8] = \&_parseInteger8;
	$parseTable->[$FLOAT32] = \&_parseFloat32;
	$parseTable->[$TRUE] = \&_parseTrue;
	$parseTable->[$FALSE] = \&_parseFalse;
	$parseTable->[$NULL] = \&_parseNull;
	$setRange->($SMALL_NEGATIVE_INT_LO, $SMALL_NEGATIVE_INT_HI, \&_parseSmallNegativeInteger);
	$setRange->($SMALL_DICTIONARY_LO, $SMALL_DICTIONARY_HI, \&_parseSmallDictionary);
	$setRange->($SHORT_STRING_LO, $SHORT_STRING_HI, \&_parseShortString);
	$setRange->($SMALL_LIST_LO, $SMALL_LIST_HI, \&_parseSmallList);
}

sub _getString {
	my ($info, $len) = @_;
	die "Missing bytes\n" if $info->{start} + $len > $info->{end};
	my $s = substr $info->{s}, $info->{start}, $len;
	$info->{start} += $len;
	return $s;
}

sub _peekChar {
	my $info = shift;
	die "Missing bytes\n" if $info->{start} >= $info->{end};
	return substr $info->{s}, $info->{start}, 1;
}

sub _getChar {
	my $info = shift;
	my $c = _peekChar($info);
	$info->{start}++;
	return $c;
}

sub _peekCharCode {
	return ord _peekChar(shift);
}

sub _getCharCode {
	return ord _getChar(shift);
}

sub _parseRencodedStringInternal {
	my $info = shift;

	die "Too much recursion!\n" if $info->{level} > MAX_RECURSION;
	$info->{level}++;

	my $code = _peekCharCode($info);
	my $func = $parseTable->[$code];
	die "Invalid rencoded byte $code\n" unless defined $func;
	my $rv = $func->($info, $code);
	$info->{level}--;
	return $rv;
}

sub _parseString {
	my ($info, $code) = @_;

	my $index = index $info->{s}, ':', $info->{start};
	die "Missing colon\n" if $index < 0;
	my $intString = _getString($info, $index - $info->{start});
	die "Invalid integer\n" unless $intString =~ /^\d+$/;
	_getChar($info);	# The colon
	my $s = _getString($info, 0+$intString);
	return $s;
}

sub _parseInteger {
	my ($info, $code) = @_;

	_getChar($info);
	my $index = index $info->{s}, chr($TERMINATOR), $info->{start};
	die "Invalid integer; missing terminator\n" if $index < 0;
	my $intString = _getString($info, $index - $info->{start});
	die "Invalid integer\n" unless $intString =~ /^-?\d+$/;
	_getChar($info);	# The terminator
	return $intString;
}

sub _parseInteger1 {
	my ($info, $code) = @_;

	_getChar($info);
	my $s = _getString($info, 1);
	return unpack "c", $s;
}

sub _parseInteger2 {
	my ($info, $code) = @_;

	_getChar($info);
	my $s = _getString($info, 2);
	return unpack "s>", $s;
}

sub _parseInteger4 {
	my ($info, $code) = @_;

	_getChar($info);
	my $s = _getString($info, 4);
	return unpack "l>", $s;
}

sub _parseInteger8 {
	my ($info, $code) = @_;

	_getChar($info);
	my $s = _getString($info, 8);
	return unpack "q>", $s;
}

sub _parseFloat32 {
	my ($info, $code) = @_;

	_getChar($info);
	my $s = _getString($info, 4);
	return unpack "f>", $s;
}

sub _parseFloat64 {
	my ($info, $code) = @_;

	_getChar($info);
	my $s = _getString($info, 8);
	return unpack "d>", $s;
}

sub _parseTrue {
	my ($info, $code) = @_;
	_getChar($info);
	return 1;
}

sub _parseFalse {
	my ($info, $code) = @_;
	_getChar($info);
	return '';
}

sub _parseNull {
	my ($info, $code) = @_;
	_getChar($info);
	return;
}

sub _parseSmallPositiveInteger {
	my ($info, $code) = @_;

	_getChar($info);
	return $code - $SMALL_POSITIVE_INT_LO;
}

sub _parseSmallNegativeInteger {
	my ($info, $code) = @_;

	_getChar($info);
	return -($code - $SMALL_NEGATIVE_INT_LO + 1);
}

sub _parseDictionary {
	my ($info, $code) = @_;

	_getChar($info);

	my $dict = {};
	while (1) {
		last if _peekCharCode($info) == $TERMINATOR;
		my $key = _parseRencodedStringInternal($info);
		die "Invalid key\n" if ref $key || !defined $key;
		my $val = _parseRencodedStringInternal($info);
		$dict->{$key} = $val;
	}
	_getChar($info);
	return $dict;
}

sub _parseSmallDictionary {
	my ($info, $code) = @_;

	_getChar($info);

	my $numElements = $code - $SMALL_DICTIONARY_LO;
	my $dict = {};
	while ($numElements-- > 0) {
		my $key = _parseRencodedStringInternal($info);
		die "Invalid key\n" if ref $key || !defined $key;
		my $val = _parseRencodedStringInternal($info);
		$dict->{$key} = $val;
	}
	return $dict;
}

sub _parseList {
	my ($info, $code) = @_;

	_getChar($info);

	my $list = [];
	while (1) {
		last if _peekCharCode($info) == $TERMINATOR;
		push @$list, scalar _parseRencodedStringInternal($info);
	}
	_getChar($info);
	return $list;
}

sub _parseSmallList {
	my ($info, $code) = @_;

	_getChar($info);

	my $numElements = $code - $SMALL_LIST_LO;
	my $list = [];
	while ($numElements-- > 0) {
		push @$list, scalar _parseRencodedStringInternal($info);
	}
	return $list;
}

sub _parseShortString {
	my ($info, $code) = @_;

	_getChar($info);
	my $len = $code - $SHORT_STRING_LO;
	my $s = _getString($info, $len);
	return $s;
}

_initialize();

1;
