```
[channel irc.server.com]
name =
password =
invite-command =
invite-http-url =
invite-http-header =
invite-http-data =
```

Create a separate **[channel]** header for each channel on each server.

#### name
> The name of the channel to join.

#### password
> The channel password. This is usually not needed.

#### invite-command
> Optional. The IRC command that invites you into the channel.

#### invite-http-url
> Optional. URL for HTTP invite request.

#### invite-http-header
> Optional. HTTP header to send, eg: Cookie: uid=12345; pass=asdfqwersdf

#### invite-http-data
> The HTTP POST data.
