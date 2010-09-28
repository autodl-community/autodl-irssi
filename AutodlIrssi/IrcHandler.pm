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
# Gets notified of new IRC announces. If it matches a filter, it starts the download and uploads
# the torrent to the destination.
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi::IrcHandler;
use AutodlIrssi::Globals;
use AutodlIrssi::Irssi;
use AutodlIrssi::MatchedRelease;
use AutodlIrssi::TextUtils qw/ decodeOctets /;

sub new {
	my ($class, $trackerManager, $filterManager, $downloadHistory) = @_;
	my $self = bless {
		trackerManager => $trackerManager,
		filterManager => $filterManager,
		downloadHistory => $downloadHistory,
	}, $class;

	irssi_signal_add("event privmsg", sub { $self->onPrivmsg(@_) });
	irssi_signal_add("event notice", sub { $self->onPrivmsg(@_) });

	return $self;
}

# Called on each PRIVMSG/NOTICE
sub onPrivmsg {
	my ($self, $server, $data, $nick, $address) = @_;

	eval {
		my ($channelName, $line) = split /\s+:/, $data, 2;
		return unless $channelName =~ /^#/;
		my $serverName = $server->{address};
		my $userName = $nick;
		my $networkName = $server->isupport('NETWORK');

		$line = decodeOctets($line);
		$self->onNewIrcLine($line, $networkName, $serverName, $channelName, $userName);
	};
	if ($@) {
		message 0, "Exception in onPrivmsg: " . formatException($@);
	}
}

sub onNewIrcLine {
	my ($self, $line, $networkName, $serverName, $channelName, $userName) = @_;

	my $ti = $self->handleNewAnnouncerLine($line, $networkName, $serverName, $channelName, $userName);
	return 0 unless defined $ti;

	my $matchedRelease = new AutodlIrssi::MatchedRelease($self->{downloadHistory});
	$matchedRelease->start($ti);
	return 1;
}

# Parses the line and returns a $ti if it matches a filter, else undef is returned.
sub handleNewAnnouncerLine {
	my ($self, $line, $networkName, $serverName, $channelName, $userName) = @_;

	my $announceParser = $self->{trackerManager}->findAnnounceParser($networkName, $serverName, $channelName, $userName);
	return unless defined $announceParser;

	my $ti = $announceParser->onNewLine($line);
	return unless defined $ti;
	return if $ti->{torrentUrl} eq "" || $ti->{torrentName} eq "";

	$ti->{filter} = $self->{filterManager}->findFilter($ti);
	return unless defined $ti->{filter};

	return $ti;
}

1;
