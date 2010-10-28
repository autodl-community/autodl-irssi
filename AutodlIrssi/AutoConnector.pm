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

# Auto connects to IRC servers and channels. Also sends identify commands.

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

	# Minimum number of seconds before we try to join a channel again
	JOIN_WAIT_SECS => 30,

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

sub new {
	my ($class, $info, $noticeObservable) = @_;

	$info->{nick} =~ s/[\x00-\x1F\s]/_/g;
	$info->{server} = canonicalizeServerName($info->{server});

	bless {
		info => $info,
		noticeObservable => $noticeObservable,
	}, $class;
}

sub _message {
	my ($self, $level, $message) = @_;
	message $level, "$self->{info}{server}: $message";
}

sub command {
	my ($self, $command) = @_;

	my $server = $self->_findServer();
	if (!defined $server) {
		$self->_message(0, "Could not find server");
		return;
	}

	$server->command($command);
}

sub cleanUp {
	my $self = shift;
	$self->_cleanUpConnectionVars();
	$self->{noticeObservable} = undef;
}

sub _getServerPort {
	my $self = shift;
	return $self->{info}{port} if $self->{info}{port} ne "";
	return 6697 if $self->{info}{ssl};
	return 6667;
}

sub _getServerName {
	my $self = shift;
	return canonicalizeServerName($self->{info}{server});
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
	delete $self->{hasTriedRegisterNick};
	delete $self->{registerStart};
	delete $self->{changingNick};
	delete $self->{changingNickTime};
	delete $self->{changingNickStart};
}

sub _setFullyConnected {
	my $self = shift;

	$self->{fullyConnected} = 1;
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
	$self->{timerTag} = irssi_timeout_add_once($secs * 1000, $handler, undef);
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
			return unless compareNicks(NICKSERV_NICK, $nick);

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

	for my $line (@$lines) {
		for my $reply (@$replies) {
			return $reply->{code} if $line =~ $reply->{regex};
		}
	}

	return;
}

sub connect {
	my $self = shift;

	if ($self->_findServer()) {
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
	my $self = shift;

	$self->_cleanUpConnectionVars();
}

# Called when we get disconnected
sub _onDisconnect {
	my $self = shift;

	$self->_cleanUpConnectionVars();
}

# Called when we're fully connected
sub _onFullyConnected {
	my $self = shift;

	return if $self->{fullyConnected};

	$self->_setFullyConnected();
	$self->_setNick();
}

sub _onRetryNickCommand {
	my $self = shift;

	$self->{changingNick} = 0;
}

sub _onNewNickName {
	my ($self, $newNick) = @_;

	$self->{changingNick} = 0;
	delete $self->{changingNickStart};
	$self->_setNick();
}

# Returns true if we're using the correct nick
sub _hasCorrectNick {
	my $self = shift;

	my $server = $self->_findServer();
	if (!defined $server) {
		$self->_message(0, "hasCorrectNick: server is undef");
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
			$self->_message(0, "Sent GHOST command. Got no reply from NickServ.");
		}
		else {
			$self->_message(3, "Killed ghost connection!");
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
		$self->_waitForNickServReply(sub { $self->_identifyReply(@_) });
		$self->command("msg " . NICKSERV_NICK . " IDENTIFY $self->{info}{identPassword}");
	}
	else {
		$self->_sendNickCommand();
		$self->_joinChannels();
	}
}

sub _identifyReply {
	my ($self, $timedOut, $lines) = @_;

	eval {
		if ($timedOut) {
			$self->_message(0, "Sent IDENTIFY command. Got no reply from NickServ.");
		}
		else {
			my $code = $self->_checkNickServReply($lines, [
				{
					code	=> "wasidentified",
					regex	=> qr/^You are already /,
				},
				{
					code	=> "identified",
					regex	=> qr/^(?:Password accepted|You are now identified|You have identified as)/,
				},
				{
					code	=> "badpassword",
					regex	=> qr/^Password incorrect/,
				},
				{
					code	=> "notregistered",
					regex	=> qr/^Your nick isn't registered/,
				},
			]);

			if (!defined $code) {
				$self->_message(0, "Got unknown IDENTIFY response:\n" . join("\n", @$lines));
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
					regex	=> qr/^Nickname \S+ registered /,
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
						$self->_sendRegisterNickCommand();
					});
					return;
				}
			}
			elsif ($code eq 'registered') {
				$self->_message(3, "Registered nick!");
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

# Returns a command string, eg. "/msg blah asdf" => "msg blah asdf"
sub fixCommandString {
	my $s = shift;
	return $s if substr($s, 0, 1) ne "/";
	return substr $s, 1;
}

# Joins all channels. Nick should already be set and identified.
sub _joinChannels {
	my $self = shift;

	my $server = $self->_findServer();
	return unless defined $server;

	my $channels = {};
	my @channels = eval { no warnings; return $server->channels(); };
	for my $channel (@channels) {
		my $channelName = canonicalizeChannelName($channel->{name});
		$channels->{$channelName} = $channel;
	}

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
			next if $elapsedTime < JOIN_WAIT_SECS;
		}
		$channelState->{sentJoin} = $currentTime;

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
					$self->_joinChannels();
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
	my $self = bless {
		servers => {},
		noticeObservable => new AutodlIrssi::NoticeObservable(),
	}, $class;

	$self->{timerTag} = irssi_timeout_add(CHECK_SERVER_STATE_SECS * 1000, sub {
		$self->_checkServerState();
	}, undef);
	$self->_createSignalsTable();
	$self->_installHandlers();

	return $self;
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

sub cleanUp {
	my $self = shift;

	irssi_timeout_remove($self->{timerTag}) if defined $self->{timerTag};
	$self->_removeHandlers();
	$self->{signals} = undef;	# Required so the handlers aren't holding a ref to us

	while (my ($key, $server) = each %{$self->{servers}}) {
		delete $self->{servers}{$key};
		$server->cleanUp();
	}
}

sub setServers {
	my ($self, $servers) = @_;

	while (my ($key, $serverInfo) = each %$servers) {
		$self->addServer($serverInfo);
	}
}

sub addServer {
	my ($self, $info) = @_;

	$info->{server} = canonicalizeServerName($info->{server});
	my $server = new AutodlIrssi::ServerConnector($info, $self->{noticeObservable});

	if ($self->{servers}{$info->{server}}) {
		$server->cleanUp();
		return;
	}
	$self->{servers}{$info->{server}} = $server;

	$server->connect();
}

sub _findServer {
	my ($self, $irssiServer) = @_;

	my $serverName = canonicalizeServerName($irssiServer->{address});
	return $self->{servers}{$serverName};
}

# Called when we're fully connected, i.e., receive one of 251, 376, or 422
sub _onMessageFullyConnected {
	my ($self, $irssiServer, $line, $nick, $address) = @_;

	eval {
		my $server = $self->_findServer($irssiServer);
		return unless defined $server;
		$server->_onFullyConnected();
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
		$server->_onConnect();
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
		$server->_onDisconnect();
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
