These options change the behavior of autodl-irssi. Place these options below the **[options]** header.

#### gui-server-port
> **Type:** Integer (valid port number)
**Example:** gui-server-port = 11111
**Description:** The port used to communicate with the ruTorrent plugin if enabled.

#### gui-server-password
> **Type:** String
**Example:** gui-server-password = abcdefg
**Description:** The password used to secure communication with the ruTorrent plugin if enabled.

#### rt-address
> **Type:** String
**Default:** Whatever is found in ~/.rtorrent.rc
**Example:** rt-address = 127.0.0.1:5000
**Description:** If you use the 'rtorrent' action (**upload-method**), then you must initialize this to your rtorrent's SCGI address. It can be ip:port (eg. 127.0.0.1:5000) or /path/to/socket.

#### update-check
> **Type:** string
**Default:** ask
**Example:** update-check = auto
**Description:** autodl-irssi can auto update itself. Valid values are **ask**, **auto**, and **disabled**. **ask** will print a message when there's a new version. **auto** will automatically update it when there's a new version. **disabled** won't do a thing when there's a new update.

#### output-level
> **Type:** Integer greater than or equal to 0.
**Default:** 3
**Description:** Set the verbosity of autodl.

#### debug
> **Type:** Boolean
**Default:** false
**Description:** Enable lower level debug messages at set **output-level**.

#### advanced-output-sites
> **Type:** Comma separated list
**Example:** advanced-output-sites = tracker1, tracker2, tracker3
**Description:** Output captured variables from announces. It's compared against the tracker type found in ~/.irssi/scripts/AutodlIrssi/trackers/*.tracker as used by the **matched-sites** filter option. Open one of the files and locate the **type="XYZ"** line. Use the value inside the quotes, eg. **XYZ**. Setting ``advanced-output-sites = all`` will enable advanced output for all trackers.

#### use-regex
> **Type:** Boolean
**Default:** false
**Description:** Changes match/except-releases filter options to use regex instead of wildcard syntax globally. This can also be set per filter.

#### max-saved-releases
> **Type:** Integer greater than or equal to 0.
**Default:** 1000
**Example:** max-saved-releases = 200
**Description:** autodl-irssi will remember the last **max-saved-releases** releases you have downloaded so it won't re-download the same file again. Only useful if **save-download-history** is enabled.

#### save-download-history
> **Type:** Boolean
**Default:** true
**Example:** save-download-history = true
**Description:** Set it to false to disable writing the last N (= **max-saved-releases**) downloaded releases to ~/.autodl/DownloadHistory.txt.

#### download-duplicates
> **Type:** Boolean
**Default:** false
**Example:** download-duplicates = true
**Description:** By default, it's false so no duplicate releases are downloaded. Set it to true if you want to download the same release if it's re-announced or announced by multiple trackers.

#### unique-torrent-names
> **Type:** Boolean
**Default:** false
**Example:** unique-torrent-names = true
**Description:** If true, all saved torrent filenames are unique (the site name is prepended to the filename). Set it to false to use the torrent release name as the filename.

#### download-retry-time-seconds
> **Type:** Integer
**Default:** 300
**Example:** download-retry-time-seconds = 120
**Description:** If a download fails, autodl-irssi will try to re-download it every 3 seconds for  **download-retry-time-seconds** seconds. It will give up after **download-retry-time-seconds** and report an error.

#### path-utorrent
> **Type:** String
**Default:** nothing
**Example:** path-utorrent = /cygdrive/c/Program Files (x86)/uTorrent/uTorrent.exe
**Description:** Set it to the path of uTorrent if you're using an **upload-type** equal to **dyndir**.

#### upload-type
> **Type:** String
**Default:** test
**Description:** Set the action to take when an announce is matched. See [actions](actions.md) for related settings.


## Wake on LAN
It's possible to wake up the computer before uploading the torrent (uTorrent webui or FTP upload). You may need to make sure your BIOS and network card have WOL enabled.

wol-mac-address = 00:11:22:33:44:55
wol-ip-address = 12.34.56.78  (or a DNS name, eg. www.blah.com)
wol-port = 9 (defaults to 9 if you leave it blank)

**wol-mac-address** is the MAC (or hardware) address of the computer's network card. Use ifconfig /all (windows) or ifconfig -a (Linux) to find out your network card's MAC address.

If you have a router, then set **wol-ip-address** to your router's public IP address, and make sure the router forwards UDP packets to port **wol-port** (default 9) to your router's internal broadcast address (usually 192.168.0.255).
