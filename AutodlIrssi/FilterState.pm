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
# Portions created by the Initial Developer are Copyright (C) 2010, 2011
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****

#
# State for each filter
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi::FilterState;
use Time::Local qw/ timegm /;

sub _createInfo {
	my ($time, $downloads) = @_;

	$time = 0 unless defined $time;
	$downloads = 0 if !defined $downloads || $downloads < 0;
	return {
		date => $time,
		downloads => $downloads,
	};
}

sub new {
	my $class = shift;

	my $self = bless {
		day => _createInfo(),
		week => _createInfo(),
		month => _createInfo(),
	}, $class;

	$self->initializeTime(time());

	return $self;
}

sub initializeTime {
	my ($self, $time) = @_;

	$time = time() unless defined $time;

	my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime $time;
	$wday = ($wday - 1) % 7;	# Sunday is last day of the week

	my $dayTime = timegm 0, 0, 0, $mday, $mon, $year;
	if ($self->{day}{date} != $dayTime) {
		$self->{day} = _createInfo($dayTime, 0);
	}

	my $weekTime = timegm 0, 0, 0, $mday, $mon, $year;
	$weekTime -= 60 * 60 * 24 * $wday;
	if ($self->{week}{date} != $weekTime) {
		$self->{week} = _createInfo($weekTime, 0);
	}

	my $monthTime = timegm 0, 0, 0, 1, $mon, $year;
	if ($self->{month}{date} != $monthTime) {
		$self->{month} = _createInfo($monthTime, 0);
	}
}

sub setDayInfo {
	my ($self, $time, $downloads) = @_;
	$self->{day} = _createInfo($time, $downloads);
}

sub setWeekInfo {
	my ($self, $time, $downloads) = @_;
	$self->{week} = _createInfo($time, $downloads);
}

sub setMonthInfo {
	my ($self, $time, $downloads) = @_;
	$self->{month} = _createInfo($time, $downloads);
}

sub getDayTime {
	return shift->{day}{date};
}

sub getDayDownloads {
	return shift->{day}{downloads};
}

sub getWeekTime {
	return shift->{week}{date};
}

sub getWeekDownloads {
	return shift->{week}{downloads};
}

sub getMonthTime {
	return shift->{month}{date};
}

sub getMonthDownloads {
	return shift->{month}{downloads};
}

sub incrementDownloads {
	my $self = shift;

	$self->{day}{downloads}++;
	$self->{week}{downloads}++;
	$self->{month}{downloads}++;

	return {
		day => $self->{day},
		week => $self->{week},
		month => $self->{month},
	};
}

sub restoreDownloadCount {
	my ($self, $obj) = @_;

	# Make sure we don't decrement it if it's a new day/week/month
	$self->{day}{downloads}-- if $self->{day} == $obj->{day};
	$self->{week}{downloads}-- if $self->{week} == $obj->{week};
	$self->{month}{downloads}-- if $self->{month} == $obj->{month};

	$obj->{day} = $obj->{week} = $obj->{month} = undef;
}

1;
