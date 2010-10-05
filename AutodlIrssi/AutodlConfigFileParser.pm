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
# Parses ~/.autodl/autodl.cfg
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi::AutodlConfigFileParser;
use AutodlIrssi::Constants;
use AutodlIrssi::TextUtils;
use base qw/ AutodlIrssi::ConfigFileParser /;

sub defaultOptions {
	return {
		updateCheck => 'ask',	# auto, ask, disabled
		userAgent => 'autodl-irssi',
		userAgentTracker => '',
		peerId => '',
		maxSavedReleases => 1000,
		saveDownloadHistory => 1,
		downloadDupeReleases => 0,
		maxDownloadRetryTimeSeconds => 5*60,
		level => 3,
		debug => 0,
		uploadType => AutodlIrssi::Constants::UPLOAD_WATCH_FOLDER(),
		uploadWatchDir => '',
		uploadFtpPath => '',
		uploadCommand => '',
		uploadArgs => '',
		uploadDyndir => '',
		pathToUtorrent => '',
		memoryLeakCheck => 0,

		webui => {
			user => '',
			password => '',
			hostname => '',
			port => 0,
			ssl => 0,
		},

		ftp => {
			user => '',
			password => '',
			hostname => '',
			port => 0,
		},
	};
}

sub new {
	my ($class, $trackerManager) = @_;

	my $self = $class->SUPER::new();

	$self->{trackerManager} = $trackerManager;
	$self->{filters} = [];
	$self->{options} = defaultOptions();

	return $self;
}

sub getFilters {
	return shift->{filters};
}

sub getOptions {
	return shift->{options};
}

sub parse {
	my ($self, $pathname) = @_;

	my $headers = $self->SUPER::parse($pathname);

	while (my ($headerType, $aryHeader) = each %$headers) {
		if ($headerType eq 'filter') {
			$self->doHeaderFilter($aryHeader);
		}
		elsif ($headerType eq 'options') {
			$self->doHeaderOptions($aryHeader);
		}
		elsif ($headerType eq 'webui') {
			$self->doHeaderWebui($aryHeader);
		}
		elsif ($headerType eq 'ftp') {
			$self->doHeaderFtp($aryHeader);
		}
		elsif ($headerType eq 'tracker') {
			$self->doHeaderTracker($aryHeader);
		}
		else {
			$self->doHeaderUnknown($aryHeader, $headerType);
		}
	}
}

sub fixHostname {
	my $hostname = shift;
	return '' unless $hostname =~ m{^(?:\w+://)?([^:/\s]+)};
	return $1;
}

sub checkValidUploadType {
	my ($self, $uploadType, $info) = @_;

	$uploadType = lc $uploadType;

	my @ary = (
		AutodlIrssi::Constants::UPLOAD_WATCH_FOLDER(),
		AutodlIrssi::Constants::UPLOAD_WEBUI(),
		AutodlIrssi::Constants::UPLOAD_FTP(),
		AutodlIrssi::Constants::UPLOAD_TOOL(),
		AutodlIrssi::Constants::UPLOAD_DYNDIR(),
	);
	for my $name (@ary) {
		return 1 if lc $name eq $uploadType;
	}

	$self->error($info->{lineNumber}, "Invalid upload-type '$uploadType'");
	return 0;
}

sub mergeHeaderOptions {
	my $aryHeader = shift;

	my $options = {};

	for my $header (@$aryHeader) {
		@$options{keys %{$header->{options}}} = values %{$header->{options}};
	}

	return $options;
}

sub setOptions {
	my ($self, $type, $dest, $options, $nameToOptionsVar) = @_;

	while (my ($name, $option) = each %$options) {
		my $destName = $nameToOptionsVar->{$name};
		if (!defined $destName || !exists $dest->{$destName} || ref $dest->{$destName}) {
			$self->error($option->{lineNumber}, "$type: Unknown option '$name'");
			next;
		}

		my $value = $option->{value};
		next if $value eq '';
		$dest->{$destName} = $value;
	}
}

# Initialize options from all [filter] headers
sub doHeaderFilter {
	my ($self, $aryHeader) = @_;

	for my $header (@$aryHeader) {
		my $filter = {
			name => '',
			enabled => 1,
			matchReleases => '',
			exceptReleases => '',
			matchCategories => '',
			exceptCategories => '',
			matchUploaders => '',
			exceptUploaders => '',
			matchSites => '',
			exceptSites => '',
			minSize => '',
			maxSize => '',
			maxPreTime => '',
			seasons => '',
			episodes => '',
			resolutions => '',
			sources => '',
			encoders => '',
			years => '',
			artists => '',
			albums => '',
			formats => '',
			bitrates => '',
			media => '',
			tags => '',
			scene => '',
			log => '',
			cue => '',
			maxTriggers => 0,
			uploadType => '',
			uploadWatchDir => '',
			uploadFtpPath => '',
			uploadCommand => '',
			uploadArgs => '',
			uploadDyndir => '',
		};

		my $options = $header->{options};
		$self->setOptions('FILTER', $filter, $options, {
			'enabled' => 'enabled',
			'match-releases' => 'matchReleases',
			'except-releases' => 'exceptReleases',
			'match-categories' => 'matchCategories',
			'except-categories' => 'exceptCategories',
			'match-uploaders' => 'matchUploaders',
			'except-uploaders' => 'exceptUploaders',
			'match-sites' => 'matchSites',
			'except-sites' => 'exceptSites',
			'min-size' => 'minSize',
			'max-size' => 'maxSize',
			'max-pretime' => 'maxPreTime',
			'seasons' => 'seasons',
			'episodes' => 'episodes',
			'resolutions' => 'resolutions',
			'sources' => 'sources',
			'encoders' => 'encoders',
			'years' => 'years',
			'shows' => 'artists',
			'albums' => 'albums',
			'formats' => 'formats',
			'bitrates' => 'bitrates',
			'media' => 'media',
			'tags' => 'tags',
			'scene' => 'scene',
			'log' => 'log',
			'cue' => 'cue',
			'max-triggers' => 'maxTriggers',
			'upload-type' => 'uploadType',
			'upload-watch-dir' => 'uploadWatchDir',
			'upload-ftp-path' => 'uploadFtpPath',
			'upload-command' => 'uploadCommand',
			'upload-args' => 'uploadArgs',
			'upload-dyndir' => 'uploadDyndir',
		});
		$filter->{name} = $header->{name};

		if ($filter->{uploadType} ne '') {
			$self->checkValidUploadType($filter->{uploadType}, $options->{'upload-type'});
		}
		$filter->{enabled} = convertStringToBoolean($filter->{enabled});
		$filter->{scene} = convertStringToBoolean($filter->{scene}) if $filter->{scene};
		$filter->{log} = convertStringToBoolean($filter->{log}) if $filter->{log};
		$filter->{cue} = convertStringToBoolean($filter->{cue}) if $filter->{cue};
		$filter->{maxTriggers} = convertStringToInteger($filter->{maxTriggers}, 0, 0);

		push @{$self->{filters}}, $filter;
	}
}

# Initialize options from all [options] headers
sub doHeaderOptions {
	my ($self, $aryHeader) = @_;

	my $options = mergeHeaderOptions($aryHeader);
	$self->setOptions('OPTIONS', $self->{options}, $options, {
		'update-check' => 'updateCheck',
		'user-agent' => 'userAgent',
		'user-agent-tracker' => 'userAgentTracker',
		'peer-id' => 'peerId',
		'max-saved-releases' => 'maxSavedReleases',
		'save-download-history' => 'saveDownloadHistory',
		'download-duplicates' => 'downloadDupeReleases',
		'download-retry-time-seconds' => 'maxDownloadRetryTimeSeconds',
		'output-level' => 'level',
		'debug' => 'debug',
		'upload-type' => 'uploadType',
		'upload-watch-dir' => 'uploadWatchDir',
		'upload-ftp-path' => 'uploadFtpPath',
		'upload-command' => 'uploadCommand',
		'upload-args' => 'uploadArgs',
		'upload-dyndir' => 'uploadDyndir',
		'path-utorrent' => 'pathToUtorrent',
		'memory-leak-check' => 'memoryLeakCheck',
	});

	$self->checkValidUploadType($self->{options}{uploadType}, $options->{'upload-type'});
	$self->{options}{maxSavedReleases} = convertStringToInteger($self->{options}{maxSavedReleases}, 1000, 0);
	$self->{options}{saveDownloadHistory} = convertStringToBoolean($self->{options}{saveDownloadHistory});
	$self->{options}{downloadDupeReleases} = convertStringToBoolean($self->{options}{downloadDupeReleases});
	$self->{options}{maxDownloadRetryTimeSeconds} = convertStringToInteger($self->{options}{maxDownloadRetryTimeSeconds}, 5*60, 0);
	$self->{options}{level} = convertStringToInteger($self->{options}{level}, 3, -1, 5);
	$self->{options}{debug} = convertStringToBoolean($self->{options}{debug});
	$self->{options}{memoryLeakCheck} = convertStringToBoolean($self->{options}{memoryLeakCheck});
	if ($self->{options}{updateCheck} ne "auto" &&
		$self->{options}{updateCheck} ne "ask" &&
		$self->{options}{updateCheck} ne "disabled") {
		$self->{options}{updateCheck} = "ask";
	}
}

# Initialize options from all [webui] headers
sub doHeaderWebui {
	my ($self, $aryHeader) = @_;

	my $options = mergeHeaderOptions($aryHeader);
	$self->setOptions('WEBUI', $self->{options}{webui}, $options, {
		user => 'user',
		password => 'password',
		hostname => 'hostname',
		port => 'port',
		ssl => 'ssl',
	});

	$self->{options}{webui}{hostname} = fixHostname($self->{options}{webui}{hostname});
	$self->{options}{webui}{port} = convertStringToInteger($self->{options}{webui}{port}, 0, 0, 65535);
	$self->{options}{webui}{ssl} = convertStringToBoolean($self->{options}{webui}{ssl});
}

# Initialize options from all [ftp] headers
sub doHeaderFtp {
	my ($self, $aryHeader) = @_;

	my $options = mergeHeaderOptions($aryHeader);
	$self->setOptions('FTP', $self->{options}{ftp}, $options, {
		user => 'user',
		password => 'password',
		hostname => 'hostname',
		port => 'port',
	});

	$self->{options}{ftp}{hostname} = fixHostname($self->{options}{ftp}{hostname});
	$self->{options}{ftp}{port} = convertStringToInteger($self->{options}{ftp}{port}, 0, 0, 65535);
}

# Initialize options from all [tracker] headers
sub doHeaderTracker {
	my ($self, $aryHeader) = @_;

	$self->{trackerManager}->resetTrackerOptions();

	for my $header (@$aryHeader) {
		my $trackerType = $header->{name};
		my $announceParser = $self->{trackerManager}->findAnnounceParserFromType($trackerType);
		if (!defined $announceParser) {
			$self->error($header->{lineNumber}, "Unknown tracker type '$trackerType'");
			next;
		}

		while (my ($name, $option) = each %{$header->{options}}) {
			my $value = $option->{value};
			if (!$announceParser->isOption($name)) {
				$self->error($option->{lineNumber}, "$trackerType: Unknown tracker option '$name'");
				next;
			}

			$announceParser->writeOption($name, $value);
		}

		my $uninitialized = $announceParser->getUninitializedDownloadVars();
		if (@$uninitialized) {
			my $uninitializedStr = join ", ", @$uninitialized;
			$self->error($header->{lineNumber}, "$trackerType: Missing option(s): $uninitializedStr");
		}
	}
}

sub doHeaderUnknown {
	my ($self, $aryHeader, $headerType) = @_;
	for my $header (@$aryHeader) {
		$self->error($header->{lineNumber}, "Unknown header '$headerType'");
	}
}

1;
