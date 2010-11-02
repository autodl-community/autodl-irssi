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

# Auto connects to IRC servers and channels. Also sends identify commands and invite requests.
# It's possible to let Irssi do this but unfortunately it works 99% of the time, not the required
# 100%. This needs to be 100% automatic.

use 5.008;
use strict;
use warnings;

package AutodlIrssi::NoticeObservable;
use AutodlIrssi::Globals;

sub new {
	my $class = shift;
	bless {
		id => 0,
		observers => {},
	}, $class;
}

# Adds an observer. An ID is returned which is used to remove the handler.
sub add {
	my ($self, $func) = @_;

	my $id = $self->{id}++;
	$self->{observers}{$id} = $func;
	return $id;
}

sub remove {
	my ($self, $id) = @_;

	return unless defined $id;
	delete $self->{observers}{$id};
}

sub notifyAll {
	my $self = shift;

	my %observersCopy = %{$self->{observers}};
	while (my ($id, $func) = each %observersCopy) {
		eval {
			$func->(@_);
		};
		if ($@) {
			chomp $@;
			message 0, "notifyAll: ex: $@";
		}
	}
}

package AutodlIrssi::ServerConnector;
use AutodlIrssi::Globals;
use AutodlIrssi::Irssi;
use AutodlIrssi::TextUtils;

use constant {
	MAX_NICK_LENGTH => 9,
	NICKSERV_NICK => "NickServ",

	# Wait at most this many seconds for a NickServ reply
	NICKSERV_TIMEOUT_SECS => 10,

	# Wait this many seconds for NickServ's next line. Assume there's none if it times out.
	NICKSERV_NEXTLINE_TIMEOUT_SECS => 2,

	# Wait this many seconds before retrying the REGISTER command
	NICKSERV_REGISTER_WAIT_SECS => 10,

	# Max number of seconds we'll try to register the nick
	NICKSERV_REGISTER_MAX_WAIT_SECS => 5*60,

	# Max number of seconds we'll wait for a nick change to succeed or fail
	CHANGE_NICK_TIMEOUT_SECS => 30,

	# Max number of seconds we'll try to set the nick before giving up (and reconnecting)
	CHANGE_NICK_RECONNECT_SECS => 5*60,
};

# Returns true if both nicks are identical
sub compareNicks {
	my ($nick1, $nick2) = @_;
	return substr($nick1, 0, MAX_NICK_LENGTH) eq substr($nick2, 0, MAX_NICK_LENGTH);
}

# Returns a command string, eg. "/msg blah asdf" => "msg blah asdf"
sub fixCommandString {
	my $s = shift;
	return $s if substr($s, 0, 1) ne "/";
	return substr $s, 1;
}

sub fixUserCommand {
	my $userCmd = shift;

	$userCmd = fixCommandString($userCmd);
	if ($userCmd =~ /^(?:echo|msg|quote)\s/i) {
		# Allowed
	}
	else {
		$userCmd = "quote $userCmd";
	}

	return "/$userCmd";
}

sub _fixServerInfo {
	my $info = shift;

	$info->{nick} =~ s/[\x00-\x1F\s]/_/g;
	$info->{server} = canonicalizeServerName($info->{server});
	$info->{identPassword} =~ s/[\x00-\x1F\s]/_/g;
	$info->{identEmail} =~ s/[\x00-\x1F\s]/_/g;
	$info->{ssl} = convertStringToBoolean($info->{ssl});
	$info->{enabled} = convertStringToBoolean($info->{enabled});

	$info->{port} = convertStringToInteger($info->{port}, undef, 1, 65535);
	if (!defined $info->{port}) {
		if ($info->{ssl}) {
			$info->{port} = 6697;
		}
		else {
			$info->{port} = 6667;
		}
	}

	while (my ($key, $channelInfo) = each %{$info->{channels}}) {
		$channelInfo->{name} =~ s/[\x00-\x1F\s]/_/g;
		$channelInfo->{name} = "#$channelInfo->{name}" unless $channelInfo->{name} =~ /^#/;
		$channelInfo->{password} =~ s/[\x00-\x1F\s]/_/g;
		$channelInfo->{inviteCommand} = fixUserCommand($channelInfo->{inviteCommand});
	}

	return $info;
}

sub new {
	my ($class, $info, $noticeObservable) = @_;

	my $self = bless {
		noticeObservable => $noticeObservable,
	}, $class;

	$self->{info} = _fixServerInfo($info),

	return $self;
}

sub cleanUp {
	my $self = shift;
	$self->_cleanUpConnectionVars();
	$self->{noticeObservable} = undef;
}

sub _message {
	my ($self, $level, $message) = @_;
	message $level, "$self->{info}{server}: $message";
}

sub _dmessage {
	my ($self, $level, $message) = @_;
	dmessage $level, "$self->{info}{server}: $message";
}

sub command {
	my ($self, $command) = @_;

	my $server = $self->_findServer();
	return unless defined $server;
	$server->command($command);
}

sub setServerInfo {
	my ($self, $info) = @_;

	_fixServerInfo($info);

	if ($self->{info}{port} != $info->{port} || $self->{info}{ssl} != $info->{ssl}) {
		$self->_message(3, "Connection settings changed. Reconnecting!");

		# Disconnect BEFORE we set the new server info or we won't be able to find the server
		# if the port got changed.
		$self->disconnect();

		$self->{info} = $info;
		$self->connect();
	}
	elsif (!compareNicks($self->{info}{nick}, $info->{nick}) ||
			$self->{info}{identPassword} ne $info->{identPassword}) {
		$self->_cleanUpNickVars();
		$self->{info} = $info;
		$self->_setNick();
	}
	else {
		# Quick test to see if we added channels. Not perfect, and if it fails, the new channels will
		# be joined after a few seconds.
		my $forceJoin = keys %{$self->{info}{channels}} != keys %{$info->{channels}};
		$self->{info} = $info;
		$self->_joinChannels() if $forceJoin;
	}
}

sub disconnect {
	my $self = shift;

	if ($self->_findServer()) {
		$self->command("disconnect");
	}
	elsif (my $reconnect = $self->_findReconnect()) {
		irssi_command("disconnect RECON-$reconnect->{tag}");
	}
	else {
		# This could happen if the server is still in the connection state. It doesn't seem to be
		# possible to find a server in that state.
		$self->_dmessage(0, "Could not disconnect. Server not found.");
	}

	# Make sure everything is cleaned up
	$self->_cleanUpConnectionVars();
}

sub _getServerPort {
	my $self = shift;
	return return $self->{info}{port};
}

sub _getServerName {
	my $self = shift;
	return canonicalizeServerName($self->{info}{server});
}

sub _getChannels {
	my $self = shift;

	my $channels = {};
	my $server = $self->_findServer();
	return $channels unless defined $server;

	my @serverChannels = eval { no warnings; return $server->channels(); };
	for my $channel (@serverChannels) {
		my $channelName = canonicalizeChannelName($channel->{name});
		$channels->{$channelName} = $channel;
	}

	return $channels;
}

# Returns the Irssi server reconnection if available or undef if none was found
sub _findReconnect {
	my $self = shift;

	my $serverName = $self->_getServerName();
	my $port = $self->_getServerPort();

	for my $reconn (irssi_reconnects()) {
		if ($serverName eq canonicalizeServerName($reconn->{address}) && $port == $reconn->{port}) {
			return $reconn;
		}
	}

	return;
}

# Returns the Irssi server if available or undef if none was found
sub _findServer {
	my $self = shift;

	my $serverName = $self->_getServerName();
	my $port = $self->_getServerPort();

	for my $server (irssi_servers()) {
		if ((!$port || $port == $server->{port}) &&
			$serverName eq canonicalizeServerName($server->{address})) {
			return $server;
		}
	}

	return;
}

sub _cleanUpConnectionVars {
	my $self = shift;

	$self->_removeNoticeHandler();
	$self->_removeTimerHandler();
	$self->{nickServLines} = undef;
	delete $self->{channelState};
	delete $self->{fullyConnected};
	delete $self->{registerStart};
	delete $self->{changingNickTime};
	$self->_cleanUpNickVars();
}

sub _cleanUpNickVars {
	my $self = shift;

	$self->_removeNoticeHandler();
	$self->_removeTimerHandler();
	delete $self->{changingNick};
	delete $self->{hasTriedRegisterNick};
	delete $self->{numTimesSentIdentify};
	delete $self->{changingNickStart};
}

sub _setFullyConnected {
	my $self = shift;

	$self->{fullyConnected} = 1;
}

# Returns true if our code is waiting for something, eg. a NickServ reply.
sub _isWaitingForSomething {
	my $self = shift;
	return defined $self->{observerId} || defined $self->{timerTag};
}

sub _installNoticeHandler {
	my ($self, $handler) = @_;

	$self->_removeNoticeHandler();
	$self->{observerId} = $self->{noticeObservable}->add($handler);
}

sub _removeNoticeHandler {
	my $self = shift;
	return unless defined $self->{observerId};
	$self->{noticeObservable}->remove($self->{observerId});
	$self->{observerId} = undef;
}

sub _installTimerHandler {
	my ($self, $secs, $handler) = @_;

	$self->_removeTimerHandler();
	$self->{timerTag} = irssi_timeout_add_once($secs * 1000, sub {
		eval {
			&$handler;
		};
		if ($@) {
			chomp $@;
			$self->_message(0, "Timer handler: $@");
		}
	}, undef);
}

sub _removeTimerHandler {
	my $self = shift;
	return unless defined $self->{timerTag};
	irssi_timeout_remove($self->{timerTag});
	$self->{timerTag} = undef;
}

# First arg to $handler will be the $timedOut flag.
sub _installNoticeHandlerWithTimeout {
	my ($self, $secs, $handler) = @_;
	$self->_installNoticeHandler(sub { $handler->(0, @_) });
	$self->_installTimerHandler($secs, sub { $handler->(1) });
}

sub _removeNoticeHandlerWithTimeout {
	my $self = shift;
	$self->_removeNoticeHandler();
	$self->_removeTimerHandler();
}

# Waits for a NickServ reply, waiting for it to send all lines. $handler->($timedOut, $aryLines)
# will be called when all lines have been received or if it timed out.
sub _waitForNickServReply {
	my ($self, $handler) = @_;

	$self->_installNoticeHandlerWithTimeout(NICKSERV_TIMEOUT_SECS, sub {
		$self->_onWaitNickServReply($handler, @_);
	})
}

sub _onWaitNickServReply {
	my ($self, $handler, $timedOut, $irssiServer, $nick, $line) = @_;

	eval {
		if ($timedOut) {
			$self->_removeNoticeHandlerWithTimeout();
			$handler->(1);
		}
		else {
			return unless canonicalizeServerName($irssiServer->{address}) eq $self->{info}{server};
			return unless compareNicks(NICKSERV_NICK, $nick);
			return if $line =~ /Your nickname does not appear to be registered/;
			return if $line =~ /This nickname is registered and protected/;
			return if $line =~ /please choose a different/;
			return if $line =~ /you do not change/;
			return if $line =~ /NickServ/;
			return if $line =~ /nick is owned by/;

			$self->{nickServLines} = [$line];
			$self->_removeNoticeHandlerWithTimeout();
			$self->_installNoticeHandlerWithTimeout(NICKSERV_NEXTLINE_TIMEOUT_SECS, sub {
				$self->_onWaitNickServNextLine($handler, @_);
			});
		}
	};
	if ($@) {
		chomp $@;
		$self->_message("_onWaitNickServReply: $@");
	}
}

sub _onWaitNickServNextLine {
	my ($self, $handler, $timedOut, $irssiServer, $nick, $line) = @_;

	eval {
		if ($timedOut) {
			$self->_removeNoticeHandlerWithTimeout();
			my $lines = $self->{nickServLines};
			$self->{nickServLines} = undef;
			$handler->(0, $lines);
		}
		else {
			return unless canonicalizeServerName($irssiServer->{address}) eq $self->{info}{server};
			return unless compareNicks(NICKSERV_NICK, $nick);

			push @{$self->{nickServLines}}, $line;

			$self->_removeNoticeHandlerWithTimeout();
			$self->_installNoticeHandlerWithTimeout(NICKSERV_NEXTLINE_TIMEOUT_SECS, sub {
				$self->_onWaitNickServNextLine($handler, @_);
			});
		}
	};
	if ($@) {
		chomp $@;
		$self->_message("_onWaitNickServReply: $@");
	}
}

sub _checkNickServReply {
	my ($self, $lines, $replies) = @_;

	# Check the lines in reverse order because the NickServ may send other lines of text
	# when we join the server, eg. "This nick is already registered......"
	for my $line (reverse @$lines) {
		for my $reply (@$replies) {
			return $reply->{code} if $line =~ $reply->{regex};
		}
	}

	return;
}

sub connect {
	my $self = shift;

	if (!$self->{info}{enabled}) {
		# Do nothing
	}
	elsif ($self->_findServer()) {
		$self->_setFullyConnected();
		$self->_setNick();
	}
	elsif ($self->_findReconnect()) {
		# Irssi will reconnect later
	}
	else {
		my $cmd = "connect";
		$cmd .= " -ssl" if $self->{info}{ssl};
		$cmd .= " $self->{info}{server}";
		$cmd .= ' ' . $self->_getServerPort();
		$cmd .= ' ""';	# Password
		$cmd .= " $self->{info}{nick}";
		irssi_command($cmd);
	}
}

# Called when we've connected to the server (TCP/IP connect)
sub _onConnect {
	my ($self, $server) = @_;

	$self->_cleanUpConnectionVars();
}

# Called when we get disconnected
sub _onDisconnect {
	my ($self, $server) = @_;

	$self->_cleanUpConnectionVars();

	if ($server->{connection_lost}) {
		# Irssi will auto join the channels as soon as we're reconnected. We don't want that!
		# Some channels won't let you change your nick while in the channel.
		$self->_removeChannels($server);
	}
}

# Removes the channels and channel windows
sub _removeChannels {
	my ($self, $server) = @_;

	for my $window (irssi_windows()) {
		my $item = $window->{active};
		next unless defined $item;
		next unless defined $item->{server};
		next unless $server->{tag} eq $item->{server}{tag};
		next unless $item->{type} eq "CHANNEL";

		$window->destroy();
	}
}

# Called when we're fully connected
sub _onFullyConnected {
	my ($self, $server) = @_;

	return if $self->{fullyConnected};

	$self->_setFullyConnected();
	$self->_setNick();
}

# Called when /nick NEWNICK failed
sub _onRetryNickCommand {
	my $self = shift;

	delete $self->{changingNick};
}

# Called when we get a new nick
sub _onNewNickName {
	my ($self, $newNick) = @_;

	$self->_cleanUpNickVars();
	$self->_setNick();
}

# Returns true if we're using the correct nick
sub _hasCorrectNick {
	my $self = shift;

	my $server = $self->_findServer();
	if (!defined $server) {
		$self->_dmessage(0, "hasCorrectNick: server is undef");
		return 0;
	}
	return compareNicks($self->{info}{nick}, $server->{nick});
}

sub _setNick {
	my $self = shift;

	if (!$self->_hasCorrectNick()) {
		$self->_forceSetNick();
	}
	else {
		$self->_sendIdentify();
	}
}

# Send a nick command if we're not using our own nick
sub _sendNickCommand {
	my $self = shift;

	if (!$self->{changingNick} && !$self->_hasCorrectNick()) {
		$self->{changingNick} = 1;
		my $currentTime = time();
		$self->{changingNickTime} = $currentTime;
		$self->{changingNickStart} = $currentTime unless defined $self->{changingNickStart};
		$self->command("nick $self->{info}{nick}");
	}
}

sub _forceSetNick {
	my $self = shift;

	if ($self->{info}{identPassword} ne "") {
		$self->_waitForNickServReply(sub { $self->_ghostReply(@_) });
		$self->command("msg " . NICKSERV_NICK . " GHOST $self->{info}{nick} $self->{info}{identPassword}");
	}
	else {
		$self->_sendNickCommand();
	}
}

sub _ghostReply {
	my ($self, $timedOut, $lines) = @_;

	eval {
		if ($timedOut) {
			$self->_dmessage(0, "Sent GHOST command. Got no reply from NickServ.");
		}
		else {
			my $code = $self->_checkNickServReply($lines, [
				{
					code	=> "notinuse",
					regex	=> qr/isn't currently in use/,
				},
				{
					code	=> "ghostkilled",
					regex	=> qr/(?:has been killed|has been ghosted)/,
				},
			]);

			if (!defined $code) {
				$self->_dmessage(0, "Got unknown GHOST response:\n" . join("\n", @$lines));
			}
			elsif ($code eq 'notinuse') {
				# Do nothing
			}
			elsif ($code eq 'ghostkilled') {
				$self->_message(3, "Killed ghost connection!");
			}
		}

		$self->_sendNickCommand();
	};
	if ($@) {
		chomp $@;
		$self->_message(0, "_ghostReply: $@");
	}
}

# Will identify current nick
sub _sendIdentify {
	my $self = shift;

	if ($self->{info}{identPassword} ne "") {
		$self->{hasTriedRegisterNick} = 0;
		$self->{numTimesSentIdentify} = 0;
		$self->_sendIdentifyNickCommand();
	}
	else {
		$self->_sendNickCommand();
		$self->_joinChannels();
	}
}

sub _sendIdentifyNickCommand {
	my $self = shift;

	$self->{numTimesSentIdentify}++;
	$self->_waitForNickServReply(sub { $self->_identifyReply(@_) });
	$self->command("msg " . NICKSERV_NICK . " IDENTIFY $self->{info}{identPassword}");
}

sub _identifyReply {
	my ($self, $timedOut, $lines) = @_;

	eval {
		if ($timedOut) {
			$self->_dmessage(0, "Sent IDENTIFY command. Got no reply from NickServ.");
		}
		else {
			my $code = $self->_checkNickServReply($lines, [
				{
					code	=> "wasidentified",
					regex	=> qr/^You are already /,
				},
				{
					code	=> "identified",
					regex	=> qr/^(?:[Pp]assword accepted|You are now identified|You have identified as)/,
				},
				{
					code	=> "badpassword",
					regex	=> qr/^Password incorrect/,
				},
				{
					code	=> "notregistered",
					regex	=> qr/^Your nick isn't registered/,
				},
				{
					code	=> "itsregistered",
					regex	=> qr/^This nickname is registered and protected/,
				},
			]);

			if (!defined $code) {
				$self->_dmessage(0, "Got unknown IDENTIFY response:\n" . join("\n", @$lines));
			}
			elsif ($code eq 'wasidentified') {
				# Do nothing
			}
			elsif ($code eq 'identified') {
				$self->_message(3, "Identified nick!");
			}
			elsif ($code eq 'badpassword') {
				$self->_message(0, "Invalid nick password!");
			}
			elsif ($code eq 'notregistered') {
				if ($self->{hasTriedRegisterNick}) {
					$self->_message(0, "IDENTIFY: Nick isn't registered!");
				}
				else {
					$self->{hasTriedRegisterNick} = 1;
					$self->_registerNick();
					return;
				}
			}
			elsif ($code eq 'itsregistered') {
				if ($self->{numTimesSentIdentify} <= 1) {
					$self->_sendIdentifyNickCommand();
					return;
				}
				else {
					$self->_message(0, "Failed to IDENTIFY nick.")
				}
			}
			else {
				$self->_message(0, "IDENTIFY: Got unknown code '$code'");
			}
		}
		$self->_joinChannels();
	};
	if ($@) {
		chomp $@;
		$self->_message(0, "_identifyReply: $@");
	}
}

sub _registerNick {
	my $self = shift;

	if ($self->{info}{identPassword} ne "") {
		if ($self->{info}{identEmail}) {
			$self->{registerStart} = time();
			$self->_sendRegisterNickCommand();
		}
		else {
			$self->_message(0, "Could not register nick: missing email address");
			$self->_joinChannels();
		}
	}
	else {
		$self->_joinChannels();
	}
}

sub _sendRegisterNickCommand {
	my $self = shift;

	$self->_waitForNickServReply(sub { $self->_registerReply(@_) });
	$self->command("msg " . NICKSERV_NICK . " REGISTER $self->{info}{identPassword} $self->{info}{identEmail}");
}

sub _registerReply {
	my ($self, $timedOut, $lines) = @_;

	eval {
		if ($timedOut) {
			$self->_message(0, "Sent REGISTER command. Got no reply from NickServ.");
		}
		else {
			my $code = $self->_checkNickServReply($lines, [
				{
					code	=> "wait",
					regex	=> qr/^(?:You must have been using this nick for|You must be connected for)/,
				},
				{
					code	=> "registered",
					regex	=> qr/^Nickname \S+ registered/,
				},
				{
					code	=> "alreadyregistered",
					regex	=> qr/^Nickname \S+ is already registered/,
				},
			]);

			if (!defined $code) {
				$self->_message(0, "Got unknown REGISTER response:\n" . join("\n", @$lines));
			}
			elsif ($code eq 'wait') {
				if (time() - $self->{registerStart} > NICKSERV_REGISTER_MAX_WAIT_SECS) {
					$self->_message(0, "Could not register nick. Timed out!");
				}
				else {
					$self->_installTimerHandler(NICKSERV_REGISTER_WAIT_SECS, sub {
						$self->_removeTimerHandler();
						$self->_sendRegisterNickCommand();
					});
					return;
				}
			}
			elsif ($code eq 'registered') {
				$self->_message(3, "Registered nick! NickServ reply:\n" . join("\n", @$lines));
			}
			elsif ($code eq 'alreadyregistered') {
				$self->_message(0, "Can't register nick! It's already been registered!");
			}
			else {
				$self->_message(0, "REGISTER: Got unknown code '$code'");
			}
		}
		delete $self->{registerStart};
		$self->_joinChannels();
	};
	if ($@) {
		chomp $@;
		$self->_message(0, "_identifyReply: $@");
	}
}

sub _getJoinWaitTimeSecs {
	my ($self, $count) = @_;
	my $wait = [30, 30, 30, 30, 1*60, 2*60, 3*60, 4*60, 5*60];
	my $secs = $wait->[$count-1];
	$secs = $wait->[-1] unless defined $secs;
	return $secs;
}

# Joins all channels. Nick should already be set and identified.
sub _joinChannels {
	my $self = shift;

	my $server = $self->_findServer();
	return unless defined $server;

	my $channels = $self->_getChannels();
	my $currentTime = time();
	while (my ($key, $channelInfo) = each %{$self->{info}{channels}}) {
		my $channelName = canonicalizeChannelName($channelInfo->{name});
		my $channel = $channels->{$channelName};

		my $channelState = $self->{channelState}{$channelName};
		$self->{channelState}{$channelName} = $channelState = {} unless defined $channelState;
		if ($channel && $channel->{joined}) {
			delete $channelState->{sentJoin};
			next;
		}

		if (defined $channelState->{sentJoin}) {
			my $elapsedTime = $currentTime - $channelState->{sentJoin};
			next if $elapsedTime < $self->_getJoinWaitTimeSecs($channelState->{sentJoinCount});
		}
		$channelState->{sentJoin} = $currentTime;
		$channelState->{sentJoinCount} = 0 unless defined $channelState->{sentJoinCount};
		$channelState->{sentJoinCount}++;

		if ($channelInfo->{inviteCommand}) {
			$server->command(fixCommandString($channelInfo->{inviteCommand}));
		}

		my $command = $channelInfo->{name};
		$command .= " $channelInfo->{password}" if $channelInfo->{password};
		$server->channels_join($command, 1);
	}
}

sub _checkState {
	my $self = shift;

	eval {
		my $currentTime = time();
		my $server = $self->_findServer();

		my $isConnected = $server && $server->{connected};
		if ($isConnected) {
			if ($self->{fullyConnected}) {
				if ($self->{changingNick}) {
					if ($currentTime - $self->{changingNickStart} > CHANGE_NICK_RECONNECT_SECS) {
						$self->_message(0, "Could not set nick. Reconnecting...");
						irssi_command("reconnect $server->{tag}");
					}
					elsif ($currentTime - $self->{changingNickTime} > CHANGE_NICK_TIMEOUT_SECS) {
						$self->{changingNick} = 0;
						$self->_setNick();
					}
					else {
						# Do nothing. Don't join the channels yet, the nick must be correct.
					}
				}
				else {
					# Don't join the channels if we're still waiting for a command, eg. when we've
					# sent the IDENTIFY command, and waiting for the response.
					if (!$self->_isWaitingForSomething()) {
						$self->_joinChannels();
					}
				}
			}
		}
		else {
			# Nothing
		}
	};
	if ($@) {
		chomp $@;
		message 0, "_checkState: $@";
	}
}

package AutodlIrssi::AutoConnector;
use AutodlIrssi::Globals;
use AutodlIrssi::Irssi;
use AutodlIrssi::TextUtils;

# How often we'll check server state (eg. that channels are joined, etc)
use constant CHECK_SERVER_STATE_SECS => 10;

sub new {
	my $class = shift;
	bless {
		enabled => 0,
		servers => {},
		noticeObservable => new AutodlIrssi::NoticeObservable(),
	}, $class;
}

sub cleanUp {
	my $self = shift;

	$self->__disable();
}

sub _createSignalsTable {
	my $self = shift;

	$self->{signals} = [
		["event 251", sub { $self->_onMessageFullyConnected(@_) }],
		["event 376", sub { $self->_onMessageFullyConnected(@_) }],
		["event 422", sub { $self->_onMessageFullyConnected(@_) }],
		["server connected", sub { $self->_onMessageConnect(@_) }],
		["server disconnected", sub { $self->_onMessageDisconnect(@_) }],
		["event notice", sub { $self->_onMessageNotice(@_) }],
		["event nick", sub { $self->_onMessageNick(@_) }],
		["event 433", sub { $self->_onMessageRetryNickCommand(@_) }],
		["event 436", sub { $self->_onMessageRetryNickCommand(@_) }],
	];
}

sub _installHandlers {
	my $self = shift;

	for my $info (@{$self->{signals}}) {
		irssi_signal_add($info->[0], $info->[1]);
	}
}

sub _removeHandlers {
	my $self = shift;

	for my $info (@{$self->{signals}}) {
		irssi_signal_remove($info->[0], $info->[1]);
	}
}

sub __enable {
	my $self = shift;

	return if $self->{enabled};
	$self->{enabled} = 1;

	$self->{timerTag} = irssi_timeout_add(CHECK_SERVER_STATE_SECS * 1000, sub {
		$self->_checkServerState();
	}, undef);
	$self->_createSignalsTable();
	$self->_installHandlers();
}

sub __disable {
	my $self = shift;

	return unless $self->{enabled};

	irssi_timeout_remove($self->{timerTag}) if defined $self->{timerTag};
	$self->_removeHandlers();
	$self->{signals} = undef;	# Required so the handlers aren't holding a ref to us

	while (my ($key, $server) = each %{$self->{servers}}) {
		delete $self->{servers}{$key};
		$server->cleanUp();
	}

	$self->{enabled} = 0;
}

# Disable auto connecting
sub disable {
	my $self = shift;
	$self->__disable();
}

sub setServers {
	my ($self, $serverInfos) = @_;

	$self->__enable();
	my $oldServers = $self->{servers};
	$self->{servers} = {};

	my $removedServers = {%$oldServers};
	my $newServers = {};
	while (my ($key, $serverInfo) = each %$serverInfos) {
		next if $serverInfo->{nick} eq "";

		my $serverName = canonicalizeServerName($serverInfo->{server});
		my $oldServer = $oldServers->{$serverName};
		if (!convertStringToBoolean($serverInfo->{enabled})) {
			$oldServer->{__disabled} = 1;
		}
		elsif ($oldServer) {
			delete $removedServers->{$serverName};
			$self->_addServer($oldServer);
			$oldServer->setServerInfo($serverInfo);
		}
		else {
			if (!defined $newServers->{$serverName}) {
				$newServers->{$serverName} = new AutodlIrssi::ServerConnector($serverInfo, $self->{noticeObservable});
			}
		}
	}

	# Disconnect all old servers
	for my $server (values %$removedServers) {
		$server->disconnect() unless $server->{__disabled};
		$server->cleanUp();
	}

	# Connect to all new servers
	for my $server (values %$newServers) {
		if ($self->_addServer($server)) {
			$server->connect();
		}
	}
}

sub _addServer {
	my ($self, $server) = @_;

	my $serverName = canonicalizeServerName($server->{info}{server});
	if ($self->{servers}{$serverName}) {
		$server->cleanUp();
		return 0;
	}

	$self->{servers}{$serverName} = $server;
	return 1;
}

sub _findServer {
	my ($self, $irssiServer) = @_;

	return unless defined $irssiServer;
	my $serverName = canonicalizeServerName($irssiServer->{address});
	return $self->{servers}{$serverName};
}

# Called when we're fully connected, i.e., receive one of 251, 376, or 422
sub _onMessageFullyConnected {
	my ($self, $irssiServer, $line, $nick, $address) = @_;

	eval {
		my $server = $self->_findServer($irssiServer);
		return unless defined $server;
		$server->_onFullyConnected($irssiServer);
	};
	if ($@) {
		chomp $@;
		message 0, "_onMessageFullyConnected: ex: $@";
	}
}

# Called when we're connected (using TCP/IP) to the server
sub _onMessageConnect {
	my ($self, $irssiServer, $line, $nick, $address) = @_;

	eval {
		my $server = $self->_findServer($irssiServer);
		return unless defined $server;
		$server->_onConnect($irssiServer);
	};
	if ($@) {
		chomp $@;
		message 0, "_onMessageConnect: ex: $@";
	}
}

sub _onMessageDisconnect {
	my ($self, $irssiServer, $line, $nick, $address) = @_;

	eval {
		my $server = $self->_findServer($irssiServer);
		return unless defined $server;
		$server->_onDisconnect($irssiServer);
	};
	if ($@) {
		chomp $@;
		message 0, "_onMessageDisconnect: ex: $@";
	}
}

sub _onMessageNotice {
	my ($self, $irssiServer, $data, $nick, $address) = @_;

	eval {
		my ($target, $line) = split /\s+:/, $data, 2;

		$self->{noticeObservable}->notifyAll($irssiServer, $nick, $line);
	};
	if ($@) {
		chomp $@;
		message 0, "_onMessageNotice: ex: $@";
	}
}

# Called when we receive a NICK command from server
sub _onMessageNick {
	my ($self, $irssiServer, $line, $nick, $address) = @_;

	eval {
		my $server = $self->_findServer($irssiServer);
		return unless defined $server;
		return unless $line =~ /^:(.*)$/;
		my $newNick = $1;
		return unless AutodlIrssi::ServerConnector::compareNicks($irssiServer->{nick}, $nick) ||
					  AutodlIrssi::ServerConnector::compareNicks($irssiServer->{nick}, $newNick);
		$server->_onNewNickName($newNick);
	};
	if ($@) {
		chomp $@;
		message 0, "_onMessageNick: ex: $@";
	}
}

# Called when we receive a 4xx NICK reply from server
sub _onMessageRetryNickCommand {
	my ($self, $irssiServer, $line, $nick, $address) = @_;

	eval {
		my $server = $self->_findServer($irssiServer);
		return unless defined $server;
		$server->_onRetryNickCommand();
	};
	if ($@) {
		chomp $@;
		message 0, "_onMessageRetryNickCommand: ex: $@";
	}
}

sub _checkServerState {
	my $self = shift;

	eval {
		while (my ($key, $server) = each %{$self->{servers}}) {
			$server->_checkState();
		}
	};
	if ($@) {
		chomp $@;
		message 0, "_checkServerState: $@";
	}
}

1;
