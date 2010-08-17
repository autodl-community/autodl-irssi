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
# Contains global functions and data most code needs.
#

use 5.008;
use strict;
use warnings;

package AutodlIrssi;

# All globals are saved here so we can easily remove them all at once when we exit.
our $g = {
	options => {
		level => 3,
		debug => 0,
	},
	trackerManager => undef,
	downloadHistory => undef,
	filterManager => undef,
	ircHandler => undef,
	tempFiles => undef,
	activeConnections => undef,
	channelMonitor => undef,
	ssl_ctx => undef,			# Used by SslSocket
	webuiToken => undef,
	webuiCookies => undef,
};

package AutodlIrssi::Globals;
use AutodlIrssi::Irssi;
use base qw/ Exporter /;
our @EXPORT = qw/ message dmessage currentTime formatException /;
our @EXPORT_OK = qw//;

sub currentTime {
	return time();
}

sub message {
	my ($level, $msg) = @_;

	if ($level <= $AutodlIrssi::g->{options}{level}) {
		$msg = "\x0300,04 ERROR: \x03 $msg" if $level == 0;
		$msg =~ s/%/%%/g;

		my $window = Irssi::window_find_name("autodl");
		if ($window) {
			$window->print($msg);
		}
		else {
			irssi_print($msg);
		}
	}
}

sub dmessage {
	if ($AutodlIrssi::g->{options}{debug}) {
		&message;
	}
}

sub formatException {
	my $s = shift;
	chomp $s;
	return $s;
}

1;
