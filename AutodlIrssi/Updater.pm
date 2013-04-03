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
# Updates the main program and tracker files
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi::Updater;
use AutodlIrssi::Globals;
use AutodlIrssi::TextUtils;
use AutodlIrssi::UpdaterXmlParser;
use AutodlIrssi::FileUtils;
use AutodlIrssi::HttpRequest;
use File::Spec;
use File::Copy;
use Archive::Zip qw/ :ERROR_CODES /;
use constant {
	UPDATE_URL => 'https://autodl-irssi-community.googlecode.com/files/update.xml?nocache',

	# This must not be a popular web browser's user agent or the update may fail
	# since SourceForge checks the user agent and sends different results depending
	# on the UA.
	UPDATE_USER_AGENT => 'autodl-irssi',
};

sub new {
	my $class = shift;
	bless {
		handler => undef,
		request => undef,
	}, $class;
}

# Throws an exception if check() hasn't been called.
sub _verifyCheckHasBeenCalled {
	my $self = shift;
	die "check() hasn't been called!\n" unless $self->{autodl};
}

# Returns true if we're checking for updates, or downloading something else
sub _isChecking {
	my $self = shift;

	# Vim Perl parser doesn't like !! so use 'not !' for now...
	return not !$self->{request};
}

# Notifies the handler, catching any exceptions. $self->{handler} will be undef'd.
sub _notifyHandler {
	my ($self, $errorMessage) = @_;

	eval {
		my $handler = $self->{handler};
	
		# Clean up before calling the handler
		$self->{handler} = undef;
		$self->{request} = undef;

		if (defined $handler) {
			$handler->($errorMessage);
		}
	};
	if ($@) {
		chomp $@;
		message 0, "Updater::_notifyHandler: ex: $@";
	}
}

# Called when an error occurs. The handler is called with the error message.
sub _error {
	my ($self, $errorMessage) = @_;
	$errorMessage ||= "Unknown error";
	$self->_notifyHandler($errorMessage);
}

# Cancel any downloads, and call the handler with an error message.
sub cancel {
	my ($self, $errorMessage) = @_;

	$errorMessage ||= "Cancelled!";
	return unless $self->_isChecking();

	if ($self->{request}) {
		$self->{request}->cancel();
	}

	$self->_error($errorMessage);
}

sub _createHttpRequest {
	my $self = shift;

	$self->{request} = new AutodlIrssi::HttpRequest();
	$self->{request}->setUserAgent(UPDATE_USER_AGENT);
	$self->{request}->setFollowNewLocation();
}

# Check for updates. $handler->($errorMessage) will be notified.
sub check {
	my ($self, $handler) = @_;

	die "Already checking for updates\n" if $self->_isChecking();

	$self->{handler} = $handler || sub {};
	$self->_createHttpRequest();
	$self->{request}->sendRequest("GET", "", UPDATE_URL, {}, sub {
		$self->_onRequestReceived(@_);
	});
}

sub _onRequestReceived {
	my ($self, $errorMessage) = @_;

	eval {
		return $self->_error("Error getting update info: $errorMessage") if $errorMessage;

		my $statusCode = $self->{request}->getResponseStatusCode();
		if ($statusCode != 200) {
			return $self->_error("Error getting update info: " . $self->{request}->getResponseStatusText());
		}

		my $xmlData = $self->{request}->getResponseData();
		my $updateParser = new AutodlIrssi::UpdaterXmlParser();
		$updateParser->parse($xmlData);
		$self->{autodl} = $updateParser->{autodl};
		$self->{trackers} = $updateParser->{trackers};

		$self->_findMissingModules();

		$self->_notifyHandler("");
	};
	if ($@) {
		chomp $@;
		$self->_error("Could not parse update.xml: $@");
	}
}

# Download the trackers file and extract it to $destDir. check() must've been called successfully.
sub updateTrackers {
	my ($self, $destDir, $handler) = @_;

	$self->_verifyCheckHasBeenCalled();
	die "Already checking for updates\n" if $self->_isChecking();

	$self->{handler} = $handler || sub {};
	$self->_createHttpRequest();
	$self->{request}->sendRequest("GET", "", $self->{trackers}{url}, {}, sub {
		$self->_onDownloadedTrackersFile(@_, $destDir);
	});
}

sub _onDownloadedTrackersFile {
	my ($self, $errorMessage, $destDir) = @_;

	eval {
		return $self->_error("Error getting trackers file: $errorMessage") if $errorMessage;

		my $statusCode = $self->{request}->getResponseStatusCode();
		if ($statusCode != 200) {
			return $self->_error("Error getting trackers file: " . $self->{request}->getResponseStatusText());
		}

		$self->_extractZipFile($self->{request}->getResponseData(), $destDir);

		$self->_notifyHandler("");
	};
	if ($@) {
		chomp $@;
		$self->_error("Error downloading trackers file: $@");
	}
}

# Download the autodl file and extract it to $destDir. check() must've been called successfully.
sub updateAutodl {
	my ($self, $destDir, $handler) = @_;

	$self->_verifyCheckHasBeenCalled();
	die "Already checking for updates\n" if $self->_isChecking();
	die "Can't update. Missing these Perl modules: @{$self->{missingModules}}\n" if $self->isMissingModules();

	$self->{handler} = $handler || sub {};
	$self->_createHttpRequest();
	$self->{request}->sendRequest("GET", "", $self->{autodl}{url}, {}, sub {
		$self->_onDownloadedAutodlFile(@_, $destDir);
	});
}

sub _onDownloadedAutodlFile {
	my ($self, $errorMessage, $destDir) = @_;

	eval {
		return $self->_error("Error getting autodl file: $errorMessage") if $errorMessage;

		my $statusCode = $self->{request}->getResponseStatusCode();
		if ($statusCode != 200) {
			return $self->_error("Error getting autodl file: " . $self->{request}->getResponseStatusText());
		}

		$self->_extractZipFile($self->{request}->getResponseData(), $destDir);

		# If autorun/autodl-irssi.pl exists, update it.
		my $srcAutodlFile = File::Spec->catfile($destDir, 'autodl-irssi.pl');
		my $dstAutodlFile = File::Spec->catfile($destDir, 'autorun', 'autodl-irssi.pl');
		if (-f $dstAutodlFile) {
			copy($srcAutodlFile, $dstAutodlFile) or die "Could not create '$dstAutodlFile': $!\n";
		}

		$self->_notifyHandler("");
	};
	if ($@) {
		chomp $@;
		$self->_error("Error downloading autodl file: $@");
	}
}

sub _extractZipFile {
	my ($self, $zipData, $destDir) = @_;

	my $tmp;
	eval {
		$tmp = createTempFile();
		binmode $tmp->{fh};
		print { $tmp->{fh} } $zipData or die "Could not write to temporary file\n";
		close $tmp->{fh};

		my $zip = new Archive::Zip();
		my $code = $zip->read($tmp->{filename});
		if ($code != AZ_OK) {
			die "Could not read zip file, code: $code, size: " . length($zipData) . "\n";
		}

		my @fileInfos = map {
			{
				destFile => appendUnixPath($destDir, $_->fileName()),
				member => $_,
			}
		} $zip->members();

		# Make sure we can write to all files
		for my $info (@fileInfos) {
			message 5, "Creating file '$info->{destFile}'";

			if ($info->{member}->isDirectory()) {
				die "Could not create directory '$info->{destFile}'\n" unless createDirectories($info->{destFile});
			}
			else {
				my ($volume, $dir, $file) = File::Spec->splitpath($info->{destFile}, 0);
				die "Could not create directory '$dir'\n" unless createDirectories($dir);
				open my $fh, '>>', $info->{destFile} or die "Could not write to file '$info->{destFile}': $!\n";
				close $fh;
			}
		}

		# Now write all data to disk. This shouldn't fail... :)
		for my $info (@fileInfos) {
			if (!$info->{member}->isDirectory()) {
				message 5, "Extracting file '$info->{destFile}'";
				if ($info->{member}->extractToFileNamed($info->{destFile}) != AZ_OK) {
					die "Could not extract file '$info->{destFile}'\n";
				}
			}
		}
	};
	if ($tmp) {
		close $tmp->{fh};
		unlink $tmp->{filename};
	}
	die $@ if $@;
}

# Updates $self->{missingModules} array with a list of all missing Perl modules
sub _findMissingModules {
	my $self = shift;

	$self->{missingModules} = [];
	for my $module (@{$self->{autodl}{modules}}) {
		eval "require $module->{name};";
		if ($@) {
			push @{$self->{missingModules}}, $module->{name};
		}
	}
}

sub isMissingModules {
	return @{shift->{missingModules}} != 0;
}

my @osInfo = (
	{
		os => 'Ubuntu, Debian',
		command => 'apt-get -y install MODULES',
		convertName => sub {
			my $module = shift;
			$module = lc $module;
			$module =~ s/::/-/g;
			return "lib$module-perl";
		},
	},
	{
		os => 'Fedora, CentOS',
		command => 'yum -y install MODULES',
		convertName => sub {
			my $module = shift;
			$module =~ s/::/-/g;
			return "perl-$module";
		},
	},
	{
		os => 'OpenSUSE',
		command => 'yast -i MODULES',
		convertName => sub {
			my $module = shift;
			$module =~ s/::/-/g;
			return "perl-$module";
		},
	},
	{
		os => 'PCLinuxOS',
		command => 'apt-get -y install MODULES',
		convertName => sub {
			my $module = shift;
			$module =~ s/::/-/g;
			return "perl-$module";
		},
	},
	{
		os => 'Mandriva Linux',
		command => 'urpmi MODULES',
		convertName => sub {
			my $module = shift;
			$module =~ s/::/-/g;
			return "perl-$module";
		},
	},
	{
		os => 'Arch Linux',
		command => 'pacman -S MODULES',
		convertName => sub {
			my $module = shift;
			$module = lc $module;
			$module =~ s/::/-/g;
			return "perl-$module";
		},
	},
	{
		os => 'FreeBSD',
		command => 'pkg_add -r MODULES',
		convertName => sub {
			my $module = shift;
			$module =~ s/::/-/g;
			return "p5-$module";
		},
	},
);

sub printMissingModules {
	my $self = shift;

	return unless $self->isMissingModules();

	message 3, "The following Perl module(s) are required, but missing:";
	message 3, "    \x0309@{$self->{missingModules}}\x03";
	message 3, "Execute one of these commands as the \x02root user\x02 to install them:";

	for my $info (@osInfo) {
		message 3, "\x0303$info->{os}\x03:";

		my $modules = "";
		for my $moduleName (@{$self->{missingModules}}) {
			my $name = $info->{convertName}->($moduleName);
			$modules .= " " if $modules;
			$modules .= $name;
		}
		my $command = $info->{command};
		$command =~ s/MODULES/$modules/g;
		message 3, "    \x0308$command\x03";
	}
}

sub getAutodlWhatsNew {
	return shift->{autodl}{whatsNew};
}

# Returns true if there's an autodl update available
sub hasAutodlUpdate {
	my ($self, $version) = @_;

	$self->_verifyCheckHasBeenCalled();
	return $self->{autodl}{version} gt $version;
}

# Returns true if there's a trackers update available
sub hasTrackersUpdate {
	my ($self, $version) = @_;

	$self->_verifyCheckHasBeenCalled();
	return $self->getTrackersVersion() > $version;
}

sub getTrackersVersion {
	my $self = shift;

	$self->_verifyCheckHasBeenCalled();
	return $self->{trackers}{version};
}

# Returns true if we're sending a request
sub isSendingRequest {
	return shift->_isChecking();
}

1;
