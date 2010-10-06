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
use AutodlIrssi::Constants;
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
use AutodlIrssi::Updater;
use AutodlIrssi::AutodlState;
use Net::SSLeay qw//;

#
# How often we'll check which IRC announcers haven't announced anything for a long time. Default is
# 10 mins.
#
use constant CHECK_BROKEN_ANNOUNCERS_SECS => 10*60;

#
# How often we'll check for updates to autodl-irssi and *.tracker files. Default is 1 hour.
#
use constant CHECK_FOR_UPDATES_SECS => 60*60;

#
# Wait at most this many seconds before closing the connection. Default is 10 mins.
#
use constant MAX_CONNECTION_WAIT_SECS => 10*60;

my $version = '1.04';
my $trackersVersion = -1;

# Called when we're enabled
sub enable {
	message 3, "\x02autodl-irssi\x02 \x02v$version\x02 is now enabled! :-)";
	message 3, "Get latest version from \x02http://sourceforge.net/projects/autodl-irssi/\x02";
	message 3, "\x0309Help forum\x03 \x02http://sourceforge.net/apps/phpbb/autodl-irssi/\x02";

	createDirectories(getAutodlSettingsDir());

	message 0, "Missing configuration file: " . getAutodlCfgFile() unless -f getAutodlCfgFile();

	my $autodlState = readAutodlState();
	$trackersVersion = $autodlState->{trackersVersion};

	$AutodlIrssi::g->{trackerManager} = new AutodlIrssi::TrackerManager($autodlState->{trackerStates});
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

	irssi_command_bind('autodl', \&command_autodl);

	irssi_timeout_add(1000, \&secondTimer, undef);
}

# Called when we're disabled
sub disable {
	message 3, "\x02autodl-irssi\x02 \x02v$version\x02 is now disabled! ;-(";

	saveAutodlState();
	$AutodlIrssi::g->{tempFiles}->deleteAll();

	# Free the SSL_CTX created by SslSocket
	if (defined $AutodlIrssi::g->{ssl_ctx}) {
		Net::SSLeay::CTX_free($AutodlIrssi::g->{ssl_ctx});
	}
}

sub readAutodlState {

	my $autodlState = {
		trackersVersion => -1,
		trackerStates => {},
	};

	eval {
		$autodlState = AutodlIrssi::AutodlState->new()->read(getAutodlStateFile());
	};
	if ($@) {
		chomp $@;
		message 0, "Could not save AutodlState.xml: ex: $@";
	}

	return $autodlState;
}

sub saveAutodlState {
	eval {
		my $autodlState = {
			trackersVersion => $trackersVersion,
			trackerStates => $AutodlIrssi::g->{trackerManager}->getTrackerStates(),
		};
		AutodlIrssi::AutodlState->new()->write(getAutodlStateFile(), $autodlState);
	};
	if ($@) {
		chomp $@;
		message 0, "Could not save AutodlState.xml: ex: $@";
	}
}

sub command_autodl {
	my ($data, $server, $witem) = @_;

	eval {
		if ($data =~ /^\s*update\s*$/i) {
			manualCheckForUpdates();
		}
		elsif ($data =~ /^\s*whatsnew\s*$/i) {
			showWhatsNew();
		}
		else {
			message 0, "Usage:";
			message 0, "    /autodl update";
			message 0, "    /autodl whatsnew";
		}
	};
	if ($@) {
		chomp $@;
		message 0, "command_autodl: ex: $@";
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
		checkForUpdates();
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
			saveAutodlState();
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
			my $networkName = $_->{server}->isupport('NETWORK');
			my $serverName = $_->{server}{address};
			my $channelName = $_->{name};
			my $announceParser = $AutodlIrssi::g->{trackerManager}->getAnnounceParserFromChannel($networkName, $serverName, $channelName);
			$announceParser ? $announceParser->getTrackerInfo()->{type} : ();
		}
		else {
			()
		}
	} irssi_channels()];
}

{
	my $updater;
	my $lastUpdateCheck;
	my $updateCheck;

	sub checkForUpdates {
		eval {
			my $elapsedSecs = defined $lastUpdateCheck ? time - $lastUpdateCheck : -1;
			if ($elapsedSecs >= MAX_CONNECTION_WAIT_SECS && defined $updater && $updater->isSendingRequest()) {
				cancelCheckForUpdates("Stuck connection!");
				return;
			}
			return if $elapsedSecs >= 0 && $elapsedSecs < CHECK_FOR_UPDATES_SECS;
			$updateCheck = $AutodlIrssi::g->{options}{updateCheck};
			forceCheckForUpdates();
		};
		if ($@) {
			chomp $@;
			message 0, "checkForUpdates: ex: $@";
		}
	}

	sub manualCheckForUpdates {
		eval {
			$updateCheck = 'manual';
			forceCheckForUpdates();
		};
		if ($@) {
			chomp $@;
			message 0, "manualCheckForUpdates: ex: $@";
		}
	}

	sub showWhatsNew {
		eval {
			$updateCheck = 'whatsnew';
			forceCheckForUpdates();
		};
		if ($@) {
			chomp $@;
			message 0, "manualCheckForUpdates: ex: $@";
		}
	}

	sub updateFailed {
		my $errorMessage = shift;
		$updater = undef;
		message 0, $errorMessage;
	}

	sub cancelCheckForUpdates {
		my $errorMessage = shift;

		$errorMessage ||= "Cancelling update!";
		return unless defined $updater;

		$updater->cancel($errorMessage);
		$updater = undef;
	}

	sub forceCheckForUpdates {
		cancelCheckForUpdates('Update check cancelled!');
		message 5, "Checking for updates...";
		$lastUpdateCheck = time;
		$updater = new AutodlIrssi::Updater();
		$updater->check(\&onUpdateFileDownloaded);
	}

	sub onUpdateFileDownloaded {
		my $errorMessage = shift;

		return updateFailed("Could not check for updates: $errorMessage") if $errorMessage;
		message 5, "Downloaded update.xml";

		my $autodlUpdateAvailable = $updater->hasAutodlUpdate($version);
		my $updateAutodl = $autodlUpdateAvailable;

		$AutodlIrssi::Constants::updatePeerId = $updater->getAutodlPeerId();
		$AutodlIrssi::Constants::updateUserAgentTracker = $updater->getAutodlUserAgentTracker();

		if ($updateCheck eq 'manual') {
			if (!$autodlUpdateAvailable) {
				message 3, "\x0309You are using the latest version!\x03";
			}
		}
		elsif ($updateCheck eq 'auto') {
			# Nothing
		}
		elsif ($updateCheck eq 'ask') {
			if ($autodlUpdateAvailable) {
				message 3, "\x0309A new version is available!\x03 Type \x02/autodl update\x02 to update or \x02/autodl whatsnew\x02.";
			}
			$updateAutodl = 0;
		}
		elsif ($updateCheck eq 'whatsnew') {
			if (!$autodlUpdateAvailable) {
				message 3, "\x0309You are using the latest version!\x03";
			}
			else {
				message 3, "New:\n" . $updater->getAutodlWhatsNew();
			}
			$updateAutodl = 0;
		}
		else {	# 'disabled' or unknown
			$updateAutodl = 0;
		}

		if ($updateAutodl) {
			if ($updater->isMissingModules()) {
				$updater->printMissingModules();
			}
			else {
				message 3, "Downloading update...";
				$updater->updateAutodl(getIrssiScriptDir(), \&onUpdatedAutodl);
				return;
			}
		}

		if ($updater->hasTrackersUpdate($trackersVersion)) {
			message 4, "Updating tracker files...";
			$updater->updateTrackers(getTrackerFilesDir(), \&onUpdatedTrackers);
			return;
		}

		$updater = undef;
	}

	sub onUpdatedAutodl {
		my $errorMessage = shift;

		$updater = undef;
		return updateFailed("Could not update autodl-irssi: $errorMessage") if $errorMessage;

		# Reset trackersVersion since we may have overwritten with older files
		$trackersVersion = 0;
		message 3, "Reloading autodl-irssi...";
		irssi_command('script load autodl-irssi');
	}

	sub onUpdatedTrackers {
		my $errorMessage = shift;

		return updateFailed("Could not update trackers: $errorMessage") if $errorMessage;

		message 4, "Trackers updated";
		$trackersVersion = $updater->getTrackersVersion();
		$updater = undef;
		reloadTrackerFiles();
	}
}

1;
