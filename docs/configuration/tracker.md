```
[tracker TYPE]
enabled =
force-ssl =
upload-delay-secs =
cookie =
passkey =
etc...
```

#### TYPE
> **TYPE** can be found in the **type="XYZ"** line in the corresponding tracker file in **~/.irssi/scripts/AutodlIrssi/trackers/**.

#### enabled
> Default (unset) is true. Set it to false to disable the tracker.

#### force-ssl
> Not all trackers support HTTPS downloads. Leave it blank for the default value (which is HTTP or HTTPS).

#### upload-delay-secs
> Set the number of seconds autodl-irssi should wait before uploading/saving the torrent. Default is 0 (no wait).

#### cookie
> Log in to your tracker's home page with your browser.
* **Chrome:** Options Menu -> Privacy -> Content Settings -> All cookies and site data
* **Firefox:** Firefox Menu -> Options -> Privacy -> Show cookies
* **Safari:** Action Menu -> Preferences -> Privacy -> Details

> Find your tracker site in the cookielist. The values needed may vary between trackers. Often these are _uid_ and _pass_.
Set the cookie like **uid=XXX; pass=YYY**, separating each key=value pair with a semicolon.

#### passkey
> First check a torrent download link if it contains it. If not you can usually find it in the generated RSS-feed URL, which you probably can generate @ yourtracker.com/getrss.php . passkeys are usually exactly 32 characters long. The passkey can also sometimes be found in your profile (click your name).

#### authkey
> See **passkey** above. For gazelle sites, it's part of the torrent download link.

**torrent_pass**
> For gazelle sites, it's part of the torrent download link.

#### uid
> Click your username and you should see the id=XXX in the address bar. That's your user id, or uid.
