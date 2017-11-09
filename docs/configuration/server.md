```
[server irc.server.com]
enabled =
port =
ssl =
nick =
ident-password =
ident-email =
server-password =
bnc =
```

#### enabled
> Default(unset) is true. Set to false to disable connecting to that server.

#### port
> The IRC server port. Default 6667 or 6697 (SSL).

#### ssl
> Set to true to use SSL connection.

#### nick
> Your IRC nick.

#### ident-password
> The password required to identify your IRC nick to NickServ. If it's not already registered, autodl-irssi will attempt to register it for you.

#### ident-email
> Optional. Required if autodl-irssi needs to register your nick.

#### server-password
> The IRC server password. This allows connection to some IRC bouncers.

#### bnc
> Set to true if you are using an IRC bouncer so you won't have to set a nick in the server header.
