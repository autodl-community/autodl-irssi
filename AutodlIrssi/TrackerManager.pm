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
# Keeps track of all tracker parsers
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi::TrackerManager;
use AutodlIrssi::Globals;
use AutodlIrssi::TrackerXmlParser;
use AutodlIrssi::AnnounceParser;
use AutodlIrssi::TextUtils;
use File::Spec;

sub new {
	my ($class, $trackerStates) = @_;

	bless {
		trackerStates => $trackerStates,
	}, $class;
}

# Returns the number of trackers we support.
sub getNumberOfTrackers {
	return scalar keys %{shift->{announceParsers}};
}

# Returns an array of absolute pathnames to all *.tracker files.
sub getTrackerFiles {
	my ($self, $baseDir) = @_;

	my @files;

	my $dh;
	opendir $dh, $baseDir or return @files;
	for my $file (readdir $dh) {
		my $pathname = File::Spec->catfile($baseDir, $file);
		next unless -f $pathname;
		next unless $file =~ /\.tracker$/;
		push @files, $pathname;
	}

	return @files;
}

# Parses all *.tracker files in $baseDir and returns an array of all trackerInfos
sub getTrackerInfos {
	my ($self, $baseDir) = @_;

	my @trackerInfos;
	for my $filename ($self->getTrackerFiles($baseDir)) {
		my $parser = new AutodlIrssi::TrackerXmlParser();

		my $trackerInfo = eval { $parser->parse($filename) };
		if ($@) {
			chomp $@;
			message 0, "Could not parse '$filename': Error: $@";
		}
		else {
			push @trackerInfos, $trackerInfo;
		}
	}
	return \@trackerInfos;
}

sub reloadTrackerFiles {
	my ($self, $trackerFilesDir) = @_;

	$self->{announceParsers} = {};
	$self->{servers} = {};

	my $currTime = time();
	for my $trackerInfo (@{$self->getTrackerInfos($trackerFilesDir)}) {
		my $type = $trackerInfo->{type};
		if (exists $self->{announceParsers}{$type}) {
			message 0, "Tracker with type '$type' has already been added.";
			next;
		}

		my $state = $self->{trackerStates}{$type};
		$self->{trackerStates}{$type} = $state = {} unless $state;
		$state->{lastAnnounce} ||= $currTime;
		$state->{lastCheck} ||= $currTime;

		my $announceParser = new AutodlIrssi::AnnounceParser($trackerInfo, $state);
		$self->{announceParsers}{$type} = $announceParser;
		$self->addAnnounceParserToServerTable($announceParser);
	}
}

sub reportBrokenAnnouncers {
	my ($self, $trackerTypes) = @_;

	my $currTime = time();
	for my $trackerType (@$trackerTypes) {
		my $announceParser = $self->{announceParsers}{$trackerType};
		my $trackerState = $self->{trackerStates}{$trackerType};
		next unless defined $announceParser && defined $trackerState;

		next if $currTime - $trackerState->{lastCheck} <= 6*60*60;
		$trackerState->{lastCheck} = $currTime;

		if ($currTime - $trackerState->{lastAnnounce} >= 24*60*60) {
			my $trackerInfo = $announceParser->getTrackerInfo();
			message(3, "\x0304WARNING\x03: \x02$trackerInfo->{longName}\x02: Nothing announced since " . localtime($trackerState->{lastAnnounce}));
		}
	}
}

sub getTrackerStates {
	my $self = shift;

	# Don't save invalid tracker types
	return {
		map {
			exists $self->{announceParsers}{$_} ? ($_, $self->{trackerStates}{$_}) : ()
		} keys %{$self->{trackerStates}}
	};
}

# Splits a comma-separated string and returns a reference to an array of strings. Empty strings are
# not returned.
sub splitCommaSeparatedList {
	my $s = shift;
	my @ary = map {
		my $a = trim $_;
		$a ne "" ? $a : ()
	} split /,/, $s;
	return \@ary;
}

# Adds the announce parser's channels to the server table.
sub addAnnounceParserToServerTable {
	my ($self, $announceParser) = @_;

	my $trackerInfo = $announceParser->getTrackerInfo();
	for my $server (@{$trackerInfo->{servers}}) {
		my $canonServerName = canonicalizeServerName($server->{name});
		for my $channelName (@{splitCommaSeparatedList($server->{channelNames})}) {
			my $channel = {
				announceParser	=> $announceParser,
				name			=> $channelName,
				announcerNames	=> splitCommaSeparatedList($server->{announcerNames}),
			};
			my $canonChannelName = canonicalizeChannelName($channelName);
			$self->{servers}{$canonServerName}{$canonChannelName} = $channel;
		}
	}
}

# Returns the announce parser or undef if none found
sub findAnnounceParser {
	my ($self, $serverName, $channelName, $announcerName) = @_;

	$serverName = canonicalizeServerName($serverName);
	$channelName = canonicalizeChannelName($channelName);
	$announcerName = lc $announcerName;

	return unless exists $self->{servers}{$serverName};
	my $channel = $self->{servers}{$serverName}{$channelName};
	return unless defined $channel;

	for my $name (@{$channel->{announcerNames}}) {
		if (lc(trim $name) eq $announcerName) {
			return $channel->{announceParser};
		}
	}
	return;
}

# Returns the AnnounceParser or undef if it doesn't exist. $type is the unique tracker type.
sub findAnnounceParserFromType {
	my ($self, $type) = @_;
	return $self->{announceParsers}{$type};
}

sub getAnnounceParsers {
	return shift->{announceParsers};
}

# Returns a list of all monitored channels for this $serverName
sub getChannels {
	my ($self, $serverName) = @_;

	$serverName = canonicalizeServerName($serverName);
	my $serverInfo = $self->{servers}{$serverName};
	return () unless defined $serverInfo;
	return map { $_->{name} } values %$serverInfo;
}

# Returns the announce parser or undef if none found
sub getAnnounceParserFromChannel {
	my ($self, $serverName, $channelName) = @_;

	$serverName = canonicalizeServerName($serverName);
	$channelName = canonicalizeChannelName($channelName);

	return unless exists $self->{servers}{$serverName};
	my $channel = $self->{servers}{$serverName}{$channelName};
	return unless defined $channel;
	return $channel->{announceParser};
}

# Resets all tracker options
sub resetTrackerOptions {
	my $self = shift;

	while (my ($trackerType, $announceParser) = each %{$self->{announceParsers}}) {
		$announceParser->resetOptions();
	}
}

1;
