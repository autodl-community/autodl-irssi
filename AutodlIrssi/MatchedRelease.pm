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
use AutodlIrssi::WOL;
use Digest::SHA1 qw/ sha1 /;
use Time::HiRes qw/ gettimeofday /;
use File::Spec;
use Errno qw/ :POSIX /;

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

# Should be called when we didn't download the torrent
sub _messageFail {
	my ($self, $level, $msg) = @_;

	if ($self->{ti} && $self->{ti}{filter}) {
		$self->{ti}{filter}{state}->restoreDownloadCount($self->{filterDlState});
	}

	message $level, $msg;
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

	$self->_messageFail(4, "Release \x02\x0309$self->{ti}{torrentName}\x03\x02 (\x02\x0302$self->{trackerInfo}{longName}\x03\x02) has already been downloaded");
}

sub _getTorrentInfoString {
	my ($self, $ti) = @_;
	$ti ||= $self->{ti};

	my $msg = "";

	$msg .= "\x02\x0309$ti->{torrentName}\x03\x02";
	$msg .= " in \x02\x0304$ti->{category}\x03\x02" if $ti->{category};

	my $sizeStr = convertToByteSizeString(convertByteSizeString($ti->{torrentSize}));
	$msg .= ", \x02\x0311$sizeStr\x03\x02" if defined $sizeStr;

	if (exists $ti->{filter} && $ti->{filter}{name}) {
		$msg .= " (\x02\x0313$ti->{filter}{name}\x02\x03)";
	}

	my $preStr = convertToTimeSinceString(convertTimeSinceString($ti->{preTime}));
	$msg .= ", pre'd \x02\x0303$preStr\x03\x02 ago" if defined $preStr;

	if (exists $ti->{announceParser}) {
		$msg .= ", \x02\x0308$self->{trackerInfo}{longName}\x03\x02";
	}

	return $msg;
}

sub _getFilename {
	my ($self, $torrentName) = @_;

	my $rawFilename;

	if ($AutodlIrssi::g->{options}{uniqueTorrentNames}) {
		# Add tracker type to the torrent name so it's possible to download the same torrent from
		# different trackers at the same time without overwriting the previous torrent file of the
		# exact same release name.
		$rawFilename = $self->{trackerInfo}{type} . '-' . $torrentName;
	}
	else {
		$rawFilename = $torrentName;
	}

	return convertToValidPathName($rawFilename . '.torrent');
}

sub start {
	my ($self, $ti) = @_;

	$self->{ti} = $ti;
	$self->{filterDlState} = $ti->{filter}{state}->incrementDownloads();
	$self->{trackerInfo} = $self->{ti}{announceParser}->getTrackerInfo();

	die "start() already called\n" if defined $self->{connId};
	$self->{connId} = $AutodlIrssi::g->{activeConnections}->add($self, "Release: '$self->{ti}{torrentName}', tracker: $self->{trackerInfo}{longName}");

	return if $self->_checkAlreadyDownloaded();

	my $missing = $self->{ti}{announceParser}->getUninitializedDownloadVars();
	if (@$missing) {
		my $missingStr = join ", ", @$missing;
		my $trackerType = $self->{trackerInfo}{type};
		my $autodlPath = getAutodlCfgFile();
		$self->_messageFail(0, "Can't download \x02\x0309$self->{ti}->{torrentName}\x03\x02. Initialize \x02\x0304$missingStr\x03\x02 below \x02\x0306[tracker $trackerType]\x03\x02 in \x02\x0307$autodlPath\x03\x02");
		return;
	}

	message(3, "Matched " . $self->_getTorrentInfoString());

	$self->{filename} = $self->_getFilename($self->{ti}{torrentName});
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
		# Yeah this is ugly
		if ($errorMessage =~ /Socket error: (\d+)/) {
			my $errno = $1;
			if ($errno == EPIPE || $errno == ECONNRESET) {
				$self->{httpRequest}->retryRequest("Got socket error. Retrying. Error: $errorMessage", sub { $self->_onTorrentDownloaded(@_) });
				return;
			}
		}

		$self->_messageFail(0, "Error downloading torrent file $self->{downloadUrl}. Error: $errorMessage");
		return;
	}

	my $statusCode = $self->{httpRequest}->getResponseStatusCode();
	if (substr($statusCode, 0, 1) == 3) {
		$self->_messageFail(0, "Got HTTP $statusCode, check your cookie settings! Torrent: $self->{ti}{torrentName}, tracker: $self->{trackerInfo}{longName}");
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
		$self->_messageFail(0, "Could not parse torrent file '$self->{ti}{torrentName}'");
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
		$self->_messageFail(3, $msg);
		return;
	}
	$self->{ti}{torrentSize} = convertToByteSizeString($self->{ti}{torrentSizeInBytes});

	$self->_onTorrentUploadWait();
}

sub _onTorrentUploadWait {
	my $self = shift;

	my $uploadDelaySecs = $self->{ti}{announceParser}->readOption("upload-delay-secs");
	if (!$uploadDelaySecs || $uploadDelaySecs <= 0) {
		$self->_onTorrentFileDownloaded();
	}
	else {
		my $msg = "Waiting $uploadDelaySecs seconds. Torrent ";
		$msg .= $self->_getTorrentInfoString({
			torrentName => $self->{ti}{torrentName},
			announceParser => $self->{ti}{announceParser},
		});
		message(3, $msg);

		irssi_timeout_add_once($uploadDelaySecs * 1000, sub {
			$self->_onTorrentFileDownloaded();
		}, undef);
	}
}

sub _checkMethodAllowed {
	my ($self, $method) = @_;

	my $allowed = trim($AutodlIrssi::g->{options}{allowed});
	return 1 if $allowed eq "";

	for my $s (split /,/, $allowed) {
		return 1 if trim($s) eq $method;
	}

	$self->_messageFail(0, "Can't save/upload torrent: '$method' is disabled!");
	return 0;
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
		$self->_messageFail(0, "Upload type not implemented, type: $self->{uploadMethod}{uploadType}");
	}
}

# Sends a Wake on LAN magic packet if enabled
sub _sendWOL {
	my $self = shift;

	eval {
		my $filter = $self->{ti}{filter};
		return unless $filter->{wolMacAddress} && $filter->{wolIpAddress};

		message 3, "Sending WOL: MAC=$filter->{wolMacAddress}, IP=$filter->{wolIpAddress}, Port=$filter->{wolPort}";
		sendWOL($filter->{wolMacAddress}, $filter->{wolIpAddress}, $filter->{wolPort});
	};
	if ($@) {
		chomp $@;
		message 0, "Could not send WOL: $@";
	}
}

sub _saveTorrentFile {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();
	return unless $self->_checkMethodAllowed("watchdir");

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
		$self->_messageFail(0, "Could not save torrent file; error: " . formatException($@));
	}
}

sub _sendTorrentFileWebui {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();
	return unless $self->_checkMethodAllowed("webui");

	eval {
		$self->_sendWOL();
		$self->_addDownload();

		message(4, "Torrent '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}): Starting webui upload.");

		my $webui = new AutodlIrssi::UtorrentWebui($AutodlIrssi::g->{options}{webui});
		$webui->addSendTorrentCommand($self->{torrentFileData}, $self->{filename});
		$webui->sendCommands(sub {
			return $self->_onWebuiUploadComplete(@_);
		});
	};
	if ($@) {
		$self->_messageFail(0, "Could not send '$self->{ti}{torrentName}' to webui; error: " . formatException($@));
	}
}

# Called when the webui upload has completed
sub _onWebuiUploadComplete {
	my ($self, $errorMessage, $commandResults) = @_;

	if ($errorMessage) {
		$self->_messageFail(0, "Could not send '$self->{ti}{torrentName}' to uTorrent (webui): error: $errorMessage");
		return;
	}
	if ($commandResults->[0]{json}{error}) {
		$self->_messageFail(0, "Error adding torrent: " . $commandResults->[0]{json}{error});
		return;
	}

	$self->_onTorrentFileUploaded("Uploaded torrent (webui)");
}

sub _sendTorrentFileFtp {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();
	return unless $self->_checkMethodAllowed("ftp");

	eval {
		$self->_sendWOL();
		$self->_addDownload();

		message(4, "Torrent '$self->{ti}{torrentName}' ($self->{trackerInfo}{longName}): Starting ftp upload.");

		# Some programs may read the torrent before we've had the chance to upload all of it, so upload
		# it with a non ".torrent" extension, and later rename it when all of the file has been uploaded.
		my $tempName = "$self->{filename}1";

		my $ftpClient = new AutodlIrssi::FtpClient();
		$ftpClient->addConnect($AutodlIrssi::g->{options}{ftp});
		$ftpClient->addChangeDirectory($self->{uploadMethod}{uploadFtpPath});
		$ftpClient->addSendFile($tempName, sub {
			my $ctx = shift;
			return "" if $ctx->{sizeLeft} == 0;
			$ctx->{sizeLeft} = 0;
			return $ctx->{torrentFileData};
		}, { torrentFileData => $self->{torrentFileData}, sizeLeft => length $self->{torrentFileData} });
		$ftpClient->addRename($tempName, $self->{filename});
		$ftpClient->addQuit();
		$ftpClient->sendCommands(sub { return $self->_onFtpUploadComplete(@_) });
	};
	if ($@) {
		$self->_messageFail(0, "Could not upload '$self->{ti}{torrentName}' to ftp; error: " . formatException($@));
	}
}

# Called when the FTP upload has completed
sub _onFtpUploadComplete {
	my ($self, $errorString) = @_;

	if ($errorString) {
		$self->_messageFail(0, "Could not upload '$self->{ti}{torrentName}' to ftp: error: $errorString");
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

	$macroReplacer->add("InfoHash", dataToHex($self->{info_hash}));

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
	return unless $self->_checkMethodAllowed("exec");

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
		$self->_messageFail(0, "Could not start program, torrent '$self->{ti}{torrentName}', error: " . formatException($@));
	}
}

sub _runUtorrentDir {
	my $self = shift;

	return if $self->_checkAlreadyDownloaded();
	return unless $self->_checkMethodAllowed("dyndir");

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
			$self->_messageFail(0, "Missing path-utorrent = XXX below [options]. Can't start uTorrent. Torrent: $self->{ti}{torrentName}");
			return;
		}

		my $torrentPathWin = $macroReplacer->replace('$(WinTorrentPathName)');
		my $args = qq#/directory "$destDir" "$torrentPathWin"#;

		# Use wine if it's not cygwin
		if (!isCygwin()) {
			$args = qq!"$command" $args!;
			$command = '/usr/bin/wine';
			unless (-x $command) {
				$self->_messageFail(0, "Wine is missing. Can't run uTorrent. Path to wine should be $command");
				return;
			}
		}

		AutodlIrssi::Exec::run($command, $args);

		$self->_addDownload();
		$self->_onTorrentFileUploaded( "Added torrent to '$destDir'");
	};
	if ($@) {
		$self->_messageFail(0, "Could not start uTorrent, torrent '$self->{ti}{torrentName}', error: " . formatException($@));
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
