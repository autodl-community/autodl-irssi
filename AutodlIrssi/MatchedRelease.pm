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
# Downloads the release from the source and uploads it to destination.
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi::MatchedRelease;
use AutodlIrssi::Irssi;
use AutodlIrssi::Constants;
use AutodlIrssi::Globals;
use AutodlIrssi::Dirs;
use AutodlIrssi::TextUtils;
use AutodlIrssi::InternetUtils;
use AutodlIrssi::HttpRequest;
use AutodlIrssi::Bencoding;
use AutodlIrssi::BitTorrent;
use AutodlIrssi::FilterManager;
use AutodlIrssi::FileUtils;
use AutodlIrssi::UtorrentWebui;
use AutodlIrssi::FtpClient;
use AutodlIrssi::MacroReplacer;
use AutodlIrssi::Exec;
use AutodlIrssi::WinUtils;
use Digest::SHA1 qw/ sha1 /;
use Time::HiRes qw/ gettimeofday /;
use File::Spec;

sub new {
	my ($class, $downloadHistory) = @_;
	bless {
		downloadHistory => $downloadHistory,
	}, $class;
}

sub DESTROY {
	my $self = shift;

	if (defined $self->{connId}) {
		$AutodlIrssi::g->{activeConnections}->remove($self->{connId});
	}
}

# Returns false if torrent hasn't been downloaded, or returns true if it has, and also prints an
# error message to the user.
sub _checkAlreadyDownloaded {
	my $self = shift;

	if (!$self->{downloadHistory}->canDownload($self->{ti})) {
		$self->_releaseAlreadyDownloaded();
		return 1;
	}

	return 0;
}

sub _releaseAlreadyDownloaded {
	my $self = shift;

	message(4, "Release \x02\x0303$self->{ti}{torrentName}\x03\x02 (\x02\x0302$self->{trackerInfo}{longName}\x03\x02) has already been downloaded");
}

sub _getTorrentInfoString {
	my ($self, $ti) = @_;
	$ti ||= $self->{ti};

	my $msg = "";

	$msg .= "\x0309$ti->{torrentName}\x03";
	$msg .= " in \x0304$ti->{category}\x03" if $ti->{category};

	my $sizeStr = convertToByteSizeString(convertByteSizeString($ti->{torrentSize}));
	$msg .= ", \x0311$sizeStr\x03" if defined $sizeStr;

	if (exists $ti->{filter} && $ti->{filter}{name}) {
		$msg .= " (\x0313$ti->{filter}{name}\x03)";
	}

	my $preStr = convertToTimeSinceString(convertTimeSinceString($ti->{preTime}));
	$msg .= ", pre'd \x0303$preStr\x03 ago" if defined $preStr;

	if (exists $ti->{announceParser}) {
		$msg .= ", \x0308$self->{trackerInfo}{longName}\x03";
	}

	return $msg;
}

sub start {
	my ($self, $ti) = @_;

	$self->{ti} = $ti;
	$self->{trackerInfo} = $self->{ti}{announceParser}->getTrackerInfo();

	die "start() already called\n" if defined $self->{connId};
	$self->{connId} = $AutodlIrssi::g->{activeConnections}->add($self, "Release: '$self->{ti}{torrentName}', tracker: $self->{trackerInfo}{longName}");

	return if $self->_checkAlreadyDownloaded();

	my $missing = $self->{ti}{announceParser}->getUninitializedDownloadVars();
	if (@$missing) {
		my $missingStr = join ", ", @$missing;
		my $trackerType = $self->{trackerInfo}{type};
		my $autodlPath = getAutodlCfgFile();
		message 0, "Can't download \x0303$self->{ti}->{torrentName}\x03. Initialize \x0304$missingStr\x03 below \x0306[tracker $trackerType]\x03 in \x0307$autodlPath\x03";
		return;
	}

	message(3, "Matched " . $self->_getTorrentInfoString());

	# Add tracker type to the torrent name so it's possible to download the same torrent from
	# different trackers at the same time without overwriting the previous torrent file of the
	# exact same release name.
	$self->{filename} = convertToValidPathName($self->{trackerInfo}{type} . '-' . $self->{ti}{torrentName} . '.torrent');
	$self->{checkregd} = $self->{ti}{announceParser}->readOption("checkregd");
	$self->{uploadMethod} = $self->{ti}{filter}{uploadType} ? $self->{ti}{filter} : $AutodlIrssi::g->{options};

	my $forceSsl = $self->{ti}{announceParser}->readOption("force-ssl");
	$self->{downloadUrl} = $forceSsl ? $self->{ti}{torrentSslUrl} : $self->{ti}{torrentUrl};

	$self->{httpRequest} = new AutodlIrssi::HttpRequest();
	if ($self->{trackerInfo}{follow302}) {
		$self->{httpRequest}->setFollowNewLocation();
	}
	$self->{startTime} = gettimeofday();
	$self->{httpRequest}->sendRequest("GET", "", $self->{downloadUrl}, $self->{ti}{httpHeaders}, sub {
		$self->_onTorrentDownloaded(@_);
	});
}

sub _onTorrentDownloaded {
	my ($self, $errorMessage) = @_;

	return if $self->_checkAlreadyDownloaded();

	if ($errorMessage) {
		message(0, "Error downloading torrent file $self->{downloadUrl}. Error: $errorMessage");
		return;
	}

	my $statusCode = $self->{httpRequest}->getResponseStatusCode();
	if (substr($statusCode, 0, 1) == 3) {
		message(0, "Got HTTP $statusCode, check your cookie settings! Torrent: $self->{ti}{torrentName}, tracker: $self->{trackerInfo}{longName}");
		return;
	}
	if (substr($statusCode, 0, 1) == 4) {
		message(0, "Got HTTP error $statusCode '" . $self->{httpRequest}->getResponseStatusText() . "' Torrent: $self->{ti}{torrentName}, tracker: $self->{trackerInfo}{longName}");
		return;
	}
	if ($statusCode != 200) {
		$self->{httpRequest}->retryRequest("HTTP error '" . $self->{httpRequest}->getResponseStatusText() . "'", sub { $self->_onTorrentDownloaded(@_) });
		return;
	}

	$self->{torrentFileData} = $self->{httpRequest}->getResponseData();
	$self->{bencRoot} = parseBencodedString($self->{torrentFileData});
	if (!$self->{bencRoot}) {
		$self->{httpRequest}->retryRequest("Invalid torrent file, first bytes: '" . substr($self->{torrentFileData}, 0, 50) . "'", sub { $self->_onTorrentDownloaded(@_) });
		return;
	}

	my $benc_info = $self->{bencRoot}->readDictionary("info");
	if (!$benc_info || !$benc_info->isDictionary()) {
		$self->{httpRequest}->retryRequest("Invalid torrent file: missing info dictionary", sub { $self->_onTorrentDownloaded(@_) });
		return;
	}

	$self->{info_hash} = sha1(substr($self->{torrentFileData}, $benc_info->{start}, $benc_info->{end} - $benc_info->{start}));

	$self->{torrentFiles} = getTorrentFiles($self->{bencRoot});
	if (!$self->{torrentFiles}) {
		message(0, "Could not parse torrent file '$self->{ti}{torrentName}'");
		return;
	}
	$self->{ti}{torrentSizeInBytes} = $self->{torrentFiles}{totalSize};

	if (!AutodlIrssi::FilterManager::checkFilterSize($self->{ti}{torrentSizeInBytes}, $self->{ti}{filter})) {
		my $msg = "Torrent ";
		$msg .= $self->_getTorrentInfoString({
			torrentName => $self->{ti}{torrentName},
			announceParser => $self->{ti}{announceParser},
		});
		$msg .= " is too big/small, size: \x02" . convertToByteSizeString($self->{ti}{torrentSizeInBytes}) . "\x02. Not downloaded.";
		message(3, $msg);
		return;
	}
	$self->{ti}{torrentSize} = convertToByteSizeString($self->{ti}{torrentSizeInBytes});

	$self->_onTorrentUploadWait();
}

sub _onTorrentUploadWait {
	my $self = shift;

	my $uploadDelaySecs = $self->{ti}{announceParser}->readOption("upload-delay-secs");
	if (!$uploadDelaySecs || $uploadDelaySecs <= 0) {
		$self->_onTorrentOkToDownload();
	}
	else {
		my $msg = "Waiting $uploadDelaySecs seconds before uploading/saving torrent ";
		$msg .= $self->_getTorrentInfoString({
			torrentName => $self->{ti}{torrentName},
			announceParser => $self->{ti}{announceParser},
		});
		message(3, $msg);

		irssi_timeout_add_once($uploadDelaySecs * 1000, sub {
			$self->_onTorrentOkToDownload();
		}, undef);
	}
}

sub _onTorrentOkToDownload {
	my $self = shift;

	if ($self->{checkregd}) {
		$self->_checkRegisteredTorrent();
	}
	else {
		$self->_onTorrentFileDownloaded();
	}
}

sub _checkRegisteredTorrent {
	my $self = shift;

	my $endTime = gettimeofday();

	my $url = $self->{bencRoot}->readDictionary("announce");
	if (!$url || !$url->isString()) {
		message(0, "Release $self->{ti}{torrentName} ($self->{trackerInfo}{longName}): Invalid torrent file: missing announce URL");
		$self->_onTorrentFileDownloaded();
		return;
	}

	my $msg = "Downloaded ";
	$msg .= $self->_getTorrentInfoString({
		torrentName => $self->{ti}{torrentName},
		announceParser => $self->{ti}{announceParser},
	});
	my $timeInSecs = sprintf("%.3f", $endTime - $self->{startTime});
	$msg .= ", took \x02\x0313$timeInSecs\x03\x02 seconds; \x02Now checking if it's registered.\x02";
	message(3, $msg);

	$self->{trackerRetryCount} = 0;
	$self->_checkRegisteredTorrentInternal();
}

sub _checkRegisteredTorrentInternal {
	my $self = shift;

	my $url = $self->_getTrackerMessageUrl("started");
	$self->{httpRequest}->setUserAgent($AutodlIrssi::g->{options}{userAgentTracker});
	$self->{httpRequest}->sendRequest("GET", "", $url, {}, sub {
		$self->_onTrackerMessageStartedSent(@_);
	});
}

sub _getTrackerMessageUrl {
	my ($self, $trackerEvent) = @_;

	my $peer_id = substr $AutodlIrssi::g->{options}{peerId} . "01234567890123456789", 0, 20;
	my $url = $self->{bencRoot}->readDictionary("announce")->{string};
	$url .= index($url, "?") == -1 ? "?" : "&";
	$url .= "info_hash=" . toUrlEncode($self->{info_hash}) .
			"&peer_id=" . toUrlEncode($peer_id) .
			"&port=12345" .
			"&uploaded=0" .
			"&downloaded=0" .
			"&left=" . (defined $self->{ti}{torrentSizeInBytes} ? $self->{ti}{torrentSizeInBytes} : 0) .
			"&corrupt=0" .
			"&key=F39AD813" .
			"&event=$trackerEvent" .
			"&numwant=0" .
			"&compact=1" .
			"&no_peer_id=1" .
			"";
	message(5, "Sending $trackerEvent event: $url");
	return $url;
}

# Called when the tracker "start" event has been sent
sub _onTrackerMessageStartedSent {
	my ($self, $errorMessage) = @_;

	if ($errorMessage) {
		message(0, "Could not check if torrent $self->{ti}{torrentName} ($self->{trackerInfo}{longName}) is registered. Error: $errorMessage");
		$self->_onTorrentFileDownloaded();
		return;
	}

	my $retryMessage;
	my $benc = parseBencodedString($self->{httpRequest}->getResponseData());
	if (!$benc) {
		$retryMessage = "Tracker returned invalid data. '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}), data: '" . substr($self->{httpRequest}->getResponseData(), 0, 50) . "'";
	}
	elsif (defined $benc->readDictionary("failure reason")) {
		$retryMessage = "Tracker returned a failure. '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}), message: '" . $benc->readDictionary("failure reason")->{string} . "'";
	}

	if ($retryMessage && !$self->{downloadHistory}->canDownload($self->{ti})) {
		$self->_releaseAlreadyDownloaded();
		return;
	}
	if ($retryMessage) {
		$self->{httpRequest}->retryRequest($retryMessage, sub { $self->_onTrackerMessageStartedSent(@_) });
		return;
	}

	message(4, "Torrent '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}) is now registered. Sending STOP event to tracker.");

	my $url = $self->_getTrackerMessageUrl("stopped");
	$self->{httpRequest}->setUserAgent($AutodlIrssi::g->{options}{userAgentTracker});
	$self->{httpRequest}->sendRequest("GET", "", $url, {}, sub {
		$self->_onTrackerMessageStoppedSent(@_);
	});
}

# Called when the tracker "stopped" event has been sent
sub _onTrackerMessageStoppedSent {
	my ($self, $errorMessage) = @_;

	if ($errorMessage) {
		message(0, "Got an error from tracker when stopping $self->{ti}{torrentName} ($self->{trackerInfo}{longName}). Error: $errorMessage");
		$self->_onTorrentFileDownloaded();
		return;
	}

	message(4, "Torrent '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}): STOP event sent to tracker.");

	$self->_onTorrentFileDownloaded();
}

# Called when the torrent file has been successfully downloaded
sub _onTorrentFileDownloaded {
	my $self = shift;

	my %funcs = (
		lc AutodlIrssi::Constants::UPLOAD_WATCH_FOLDER()	=> \&_saveTorrentFile,
		lc AutodlIrssi::Constants::UPLOAD_WEBUI()			=> \&_sendTorrentFileWebui,
		lc AutodlIrssi::Constants::UPLOAD_FTP()				=> \&_sendTorrentFileFtp,
		lc AutodlIrssi::Constants::UPLOAD_TOOL()			=> \&_runProgram,
		lc AutodlIrssi::Constants::UPLOAD_DYNDIR()			=> \&_runUtorrentDir,
	);

	my $func = $funcs{lc $self->{uploadMethod}{uploadType}};
	if (defined $func) {
		$func->($self);
	}
	else {
		message(0, "Upload type not implemented, type: $self->{uploadMethod}{uploadType}");
	}
}

sub _saveTorrentFile {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();

	eval {
		# Save it to a temporary name with a different extension, and when all data has been written
		# to the file, rename it to the real filename.
		my $pathname = File::Spec->catfile($self->{uploadMethod}{uploadWatchDir}, $self->{filename});
		my $tempname = $pathname . '1';
		createDirectories($self->{uploadMethod}{uploadWatchDir});
		saveRawDataToFile($tempname, $self->{torrentFileData});
		rename $tempname, $pathname or die "Could not rename $tempname => $pathname\n";

		$self->_addDownload();
		$self->_onTorrentFileUploaded("Saved torrent");
	};
	if ($@) {
		message(0, "Could not save torrent file; error: " . formatException($@));
	}
}

sub _sendTorrentFileWebui {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();

	eval {
		$self->_addDownload();

		message(4, "Torrent '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}): Starting webui upload.");

		my $webui = new AutodlIrssi::UtorrentWebui($AutodlIrssi::g->{options}{webui});
		$webui->addSendTorrentCommand($self->{torrentFileData}, $self->{filename});
		$webui->sendCommands(sub {
			return $self->_onWebuiUploadComplete(@_);
		});
	};
	if ($@) {
		message(0, "Could not send '$self->{ti}{torrentName}' to webui; error: " . formatException($@));
	}
}

# Called when the webui upload has completed
sub _onWebuiUploadComplete {
	my ($self, $errorMessage, $commandResults) = @_;

	if ($errorMessage) {
		message(0, "Could not send '$self->{ti}{torrentName}' to uTorrent (webui): error: $errorMessage");
		return;
	}
	if ($commandResults->[0]{json}{error}) {
		message(0, "Error adding torrent: " . $commandResults->[0]{json}{error});
		return;
	}

	$self->_onTorrentFileUploaded("Uploaded torrent (webui)");
}

sub _sendTorrentFileFtp {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();

	eval {
		$self->_addDownload();

		message(4, "Torrent '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}): Starting ftp upload.");

		my $ftpClient = new AutodlIrssi::FtpClient();
		$ftpClient->addConnect($AutodlIrssi::g->{options}{ftp});
		$ftpClient->addChangeDirectory($self->{uploadMethod}{uploadFtpPath});
		$ftpClient->addSendFile($self->{filename}, sub {
			my $ctx = shift;
			return "" if $ctx->{sizeLeft} == 0;
			$ctx->{sizeLeft} = 0;
			return $ctx->{torrentFileData};
		}, { torrentFileData => $self->{torrentFileData}, sizeLeft => length $self->{torrentFileData} });
		$ftpClient->addQuit();
		$ftpClient->sendCommands(sub { return $self->_onFtpUploadComplete(@_) });
	};
	if ($@) {
		message(0, "Could not upload '$self->{ti}{torrentName}' to ftp; error: " . formatException($@));
	}
}

# Called when the FTP upload has completed
sub _onFtpUploadComplete {
	my ($self, $errorString) = @_;

	if ($errorString) {
		message(0, "Could not upload '$self->{ti}{torrentName}' to ftp: error: $errorString");
		return;
	}

	$self->_onTorrentFileUploaded("Uploaded torrent (ftp)");
}

sub _getMacroReplacer {
	my ($self, $torrentPathname) = @_;

	my $macroReplacer = new AutodlIrssi::MacroReplacer();
	$macroReplacer->addTorrentInfo($self->{ti});
	$macroReplacer->addTimes();
	if ($torrentPathname) {
		$macroReplacer->add("TorrentPathName", $torrentPathname);
		$macroReplacer->add("WinTorrentPathName", getWindowsPath($torrentPathname));
	}

	return $macroReplacer;
}

# Write data to a temporary file. Returns the filename
sub _writeTempFile {
	my ($self, $data) = @_;

	my $tempInfo = createTempFile();
	$AutodlIrssi::g->{tempFiles}->add($tempInfo->{filename});
	binmode $tempInfo->{fh};
	print { $tempInfo->{fh} } $data or die "Could not write to temporary file\n";
	close $tempInfo->{fh};

	return $tempInfo->{filename};
}

sub _runProgram {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();

	eval {
		my $filename = $self->_writeTempFile($self->{torrentFileData});

		my $macroReplacer = $self->_getMacroReplacer($filename);
		my $command = $macroReplacer->replace($self->{uploadMethod}{uploadCommand});
		my $args = $macroReplacer->replace($self->{uploadMethod}{uploadArgs});

		AutodlIrssi::Exec::run($command, $args);

		$self->_addDownload();
		$self->_onTorrentFileUploaded("Started command: '$command', args: '$args'");
	};
	if ($@) {
		message(0, "Could not start program, torrent '$self->{ti}{torrentName}', error: " . formatException($@));
	}
}

sub _runUtorrentDir {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();

	eval {
		my $filename = $self->_writeTempFile($self->{torrentFileData});
		my $macroReplacer = $self->_getMacroReplacer($filename);

		my $dyndir = $self->{uploadMethod}{uploadDyndir};
		$dyndir =~ s#/#\\#g;
		my @dirNames = split /\\/, $dyndir;
		my $destDir = "";
		if (@dirNames && $dirNames[0] =~ /^\w:$/) {
			$destDir = shift @dirNames;
		}
		for my $temp (@dirNames) {
			my $dirName = trim $macroReplacer->replace($temp);
			next unless $dirName;
			$destDir .= '\\' . convertToValidPathName($dirName);
		}

		my $command = $AutodlIrssi::g->{options}{pathToUtorrent};
		if ($command eq "") {
			message(0, "Missing path-utorrent = XXX below [options]. Can't start uTorrent. Torrent: $self->{ti}{torrentName}");
			return;
		}

		my $torrentPathWin = $macroReplacer->replace('$(WinTorrentPathName)');
		my $args = qq!/directory "$destDir" "$torrentPathWin"!;

		# Use wine if it's not cygwin
		if (!isCygwin()) {
			$args = qq!"$command" $args!;
			$command = '/usr/bin/wine';
			unless (-x $command) {
				message 0, "Wine is missing. Can't run uTorrent. Path to wine should be $command";
				return;
			}
		}

		AutodlIrssi::Exec::run($command, $args);

		$self->_addDownload();
		$self->_onTorrentFileUploaded( "Added torrent to '$destDir'");
	};
	if ($@) {
		message(0, "Could not start uTorrent, torrent '$self->{ti}{torrentName}', error: " . formatException($@));
	}
}

sub _addDownload {
	my $self = shift;
	$self->{downloadHistory}->addDownload($self->{ti}, $self->{downloadUrl});
}

sub _onTorrentFileUploaded {
	my ($self, $message) = @_;

	$self->_displayTotalTime(scalar gettimeofday(), $message);
}

sub _displayTotalTime {
	my ($self, $endTime, $startMsg) = @_;

	my $msg = "$startMsg ";
	$msg .= $self->_getTorrentInfoString({
		torrentName => $self->{ti}{torrentName},
		announceParser => $self->{ti}{announceParser},
	});
	my $totalTime = sprintf("%.3f", $endTime - $self->{startTime});
	$msg .= ", total time \x02\x0313$totalTime\x03\x02 seconds";
	message(3, $msg);
}

1;
