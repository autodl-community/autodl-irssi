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
# Loaded by autodl-irssi.pl, and this is where all the startup code is.
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi;
use AutodlIrssi::Irssi;
use AutodlIrssi::Globals;
use AutodlIrssi::Dirs;
use AutodlIrssi::FileUtils;
use AutodlIrssi::TrackerManager;
use AutodlIrssi::AutodlConfigFileParser;
use AutodlIrssi::DownloadHistory;
use AutodlIrssi::FilterManager;
use AutodlIrssi::IrcHandler;
use AutodlIrssi::TempFiles;
use AutodlIrssi::ActiveConnections;
use AutodlIrssi::ChannelMonitor;
use Net::SSLeay qw//;

#
# How often we'll check which IRC announcers haven't announced anything for a long time.
#
use constant CHECK_BROKEN_ANNOUNCERS_SECS => 10*60;

my $version = '1.01';

# Called when we're enabled
sub enable {
	message 3, "\x02autodl-irssi\x02 \x02v$version\x02 is now enabled! :-)";
	message 3, "Get latest version from \x02http://sourceforge.net/projects/autodl-irssi/\x02";
	message 3, "\x0309Help forum\x03 \x02http://sourceforge.net/apps/phpbb/autodl-irssi/\x02";

	createDirectories(getAutodlSettingsDir());

	message 0, "Missing configuration file: " . getAutodlCfgFile() unless -f getAutodlCfgFile();

	$AutodlIrssi::g->{trackerManager} = new AutodlIrssi::TrackerManager();
	$AutodlIrssi::g->{downloadHistory} = new AutodlIrssi::DownloadHistory(getDownloadHistoryFile());
	$AutodlIrssi::g->{filterManager} = new AutodlIrssi::FilterManager();
	$AutodlIrssi::g->{tempFiles} = new AutodlIrssi::TempFiles();
	$AutodlIrssi::g->{activeConnections} = new AutodlIrssi::ActiveConnections();
	$AutodlIrssi::g->{channelMonitor} = new AutodlIrssi::ChannelMonitor($AutodlIrssi::g->{trackerManager});

	reloadTrackerFiles();
	reloadAutodlConfigFile();
	readDownloadHistoryFile();

	$AutodlIrssi::g->{ircHandler} = new AutodlIrssi::IrcHandler($AutodlIrssi::g->{trackerManager},
																$AutodlIrssi::g->{filterManager},
																$AutodlIrssi::g->{downloadHistory});

	irssi_timeout_add(1000, \&secondTimer, undef);
}

# Called when we're disabled
sub disable {
	message 3, "\x02autodl-irssi\x02 \x02v$version\x02 is now disabled! ;-(";

	$AutodlIrssi::g->{trackerManager}->saveTrackersState();
	$AutodlIrssi::g->{tempFiles}->deleteAll();

	# Free the SSL_CTX created by SslSocket
	if (defined $AutodlIrssi::g->{ssl_ctx}) {
		Net::SSLeay::CTX_free($AutodlIrssi::g->{ssl_ctx});
	}
}

sub readDownloadHistoryFile {
	eval {
		$AutodlIrssi::g->{downloadHistory}->loadHistoryFile();
	};
	if ($@) {
		message 0, "Error when reading download history file: " . formatException($@);
	}
	else {
		my $numLoaded = $AutodlIrssi::g->{downloadHistory}->getNumFiles();
		message 3, "Loaded \x02" . $numLoaded . "\x02 release" . ($numLoaded == 1 ? "" : "s") . " from history file.";
	}
}

sub reloadTrackerFiles {
	eval {
		$AutodlIrssi::g->{trackerManager}->reloadTrackerFiles(getTrackerFilesDir());
	};
	if ($@) {
		message 0, "Error when reading tracker files: " . formatException($@);
	}
	else {
		message 3, "Added \x02" . $AutodlIrssi::g->{trackerManager}->getNumberOfTrackers() . "\x02 trackers";
	}
}

my $autodlCfgTime;
sub reloadAutodlConfigFile {

	return unless -f getAutodlCfgFile();

	my $reload = 0;
	if (!defined $autodlCfgTime) {
		$reload = 1;
	}
	else {
		my $newTime = (stat getAutodlCfgFile())[9];	# Get mtime
		$reload = 1 if $newTime > $autodlCfgTime;
	}

	if ($reload) {
		message 3, "autodl.cfg modified, re-reading it..." if defined $autodlCfgTime;
		$autodlCfgTime = (stat getAutodlCfgFile())[9];	# Get mtime
		forceReloadAutodlConfigFile();
	}
}

sub forceReloadAutodlConfigFile {
	eval {
		my $configFileParser = new AutodlIrssi::AutodlConfigFileParser($AutodlIrssi::g->{trackerManager});
		$configFileParser->parse(getAutodlCfgFile());
		$AutodlIrssi::g->{filterManager}->setFilters($configFileParser->getFilters());
		$AutodlIrssi::g->{options} = $configFileParser->getOptions();
	};
	if ($@) {
		message 0, "Error when reading autodl.cfg: " . formatException($@);
	}
	else {
		message 3, "Added \x02" . $AutodlIrssi::g->{filterManager}->getNumFilters() . "\x02 filters";
	}
}

# It's called once every second by Irssi
sub secondTimer {
	eval {
		$AutodlIrssi::g->{tempFiles}->deleteOld();
		reloadAutodlConfigFile();
		activeConnectionsCheck();
		reportBrokenAnnouncers();
	};
	if ($@) {
		message 0, "secondTimer: ex: " . formatException($@);
	}
}

{
	my $counter = 0;
	sub activeConnectionsCheck {
		return unless ++$counter >= 60;
		$counter = 0;
		$AutodlIrssi::g->{activeConnections}->reportMemoryLeaks();
	}
}

{
	my $counter = 0;
	sub reportBrokenAnnouncers {
		return unless ++$counter >= CHECK_BROKEN_ANNOUNCERS_SECS;
		$counter = 0;

		eval {
			my $channels = getActiveAnnounceParserTypes();
			$AutodlIrssi::g->{trackerManager}->reportBrokenAnnouncers($channels);
			$AutodlIrssi::g->{trackerManager}->saveTrackersState();
		};
		if ($@) {
			chomp $@;
			message 0, "reportBrokenAnnouncers: ex: $@";
		}
	}
}

# Returns an array ref of all monitored channels we've joined
sub getActiveAnnounceParserTypes {
	return [map {
		if ($_->{joined}) {
			my $serverName = $_->{server}{address};
			my $channelName = $_->{name};
			my $announceParser = $AutodlIrssi::g->{trackerManager}->getAnnounceParserFromChannel($serverName, $channelName);
			$announceParser ? $announceParser->getTrackerInfo()->{type} : ();
		}
		else {
			()
		}
	} irssi_channels()];
}

1;
