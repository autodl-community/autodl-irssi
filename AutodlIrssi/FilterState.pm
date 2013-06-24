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
		hour => _createInfo(),
		day => _createInfo(),
		week => _createInfo(),
		month => _createInfo(),
		total => _createInfo(),
	}, $class;

	$self->initializeTime(time());

	return $self;
}

sub initializeTime {
	my ($self, $time) = @_;

	$time = time() unless defined $time;

	my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime $time;
	$wday = ($wday - 1) % 7;	# Sunday is last day of the week

	my $hourTime = timegm 0, 0, $hour, $mday, $mon, $year;
	if ($self->{hour}{date} != $hourTime) {
		$self->{hour} = _createInfo($hourTime, 0);
	}

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

	if ($self->{total}{date} != $dayTime) {
		$self->{total} = _createInfo($dayTime, 0);
	}
}

sub setHourInfo {
	my ($self, $time, $downloads) = @_;
	$self->{hour} = _createInfo($time, $downloads);
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

sub setTotalInfo {
	my ($self, $time, $downloads) = @_;
	$self->{total} = _createInfo($time, $downloads);
}

sub getHourTime {
	return shift->{hour}{date};
}

sub getHourDownloads {
	return shift->{hour}{downloads};
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

sub getTotalTime {
	return shift->{total}{date};
}

sub getTotalDownloads {
	return shift->{total}{downloads};
}

sub incrementDownloads {
	my $self = shift;

	$self->{hour}{downloads}++;
	$self->{day}{downloads}++;
	$self->{week}{downloads}++;
	$self->{month}{downloads}++;
	$self->{total}{downloads}++;

	return {
		hour => $self->{hour},
		day => $self->{day},
		week => $self->{week},
		month => $self->{month},
		total => $self->{total},
	};
}

sub restoreDownloadCount {
	my ($self, $obj) = @_;

	# Make sure we don't decrement it if it's a new day/week/month
	$self->{hour}{downloads}-- if $self->{hour} == $obj->{hour};
	$self->{day}{downloads}-- if $self->{day} == $obj->{day};
	$self->{week}{downloads}-- if $self->{week} == $obj->{week};
	$self->{month}{downloads}-- if $self->{month} == $obj->{month};
	$self->{total}{downloads}-- if $self->{total} == $obj->{total};

	$obj->{hour} = $obj->{day} = $obj->{week} = $obj->{month} = $obj->{total} = undef;
}

1;
