* [General](#general-options)
* [Torrent Actions](#torrent-actions)
	* [rTorrent](#rtorrent)
	* [Watch Directory](#watch-directory)
	* [uTorrent WebUI](#utorrent-webui)
	* [FTP](#ftp)
	* [Execute a Command](#execute-a-command)
	* [uTorrent Dynamic Directory](#utorrent-dynamic-directory)
* [Macros](#macros)
* [Wake on LAN](#wake-on-lan)

## General Options

These options change the behavior of autodl-irssi. Place these options below the **[options]** header.

##### rt-address
> **Type:** string
**Default:** Whatever is found in ~/.rtorrent.rc
**Example:** rt-address = 127.0.0.1:5000
**Description:** If you use the 'rtorrent' action (**upload-method**), then you must initialize this to your rtorrent's SCGI address. It can be ip:port (eg. 127.0.0.1:5000) or /path/to/socket. **NOTE:** This option can only be set in autodl2.cfg, **not** autodl.cfg.

##### update-check
> **Type:** string
**Default:** ask
**Example:** update-check = auto
**Description:** autodl-irssi can auto update itself. Valid values are **ask**, **auto**, and **disabled**. **ask** will print a message when there's a new version. **auto** will automatically update it when there's a new version. **disabled** won't do a thing when there's a new update.

##### output-level
> **Type:** Integer greater than or equal to 0.
**Default:** 3
**Description:** Set the verbosity of autodl.

##### debug
> **Type:** Boolean
**Default:** false
**Description:** Enable lower level debug messages at set **output-level**.

##### advanced-output-sites
> **Type:** Comma separated list
**Example:** advanced-output-sites = tracker1, tracker2, tracker3
**Description:** Output captured variables from announces. It's compared against the tracker type found in ~/.irssi/scripts/AutodlIrssi/trackers/*.tracker as used by the **matched-sites** filter option. Open one of the files and locate the **type="XYZ"** line. Use the value inside the quotes, eg. **XYZ**. Setting ``advanced-output-sites = all`` will enable advanced output for all trackers.

##### use-regex
> **Type:** Boolean
**Default:** false
**Description:** Changes match/except-releases filter options to use regex instead of wildcard syntax globally. This can also be set per filter.

##### max-saved-releases
> **Type:** Integer greater than or equal to 0.
**Default:** 1000
**Example:** max-saved-releases = 200
**Description:** autodl-irssi will remember the last **max-saved-releases** releases you have downloaded so it won't re-download the same file again. Only useful if **save-download-history** is enabled.

##### save-download-history
> **Type:** Boolean
**Default:** true
**Example:** save-download-history = true
**Description:** Set it to false to disable writing the last N (= **max-saved-releases**) downloaded releases to ~/.autodl/DownloadHistory.txt.

##### download-duplicates
> **Type:** Boolean
**Default:** false
**Example:** download-duplicates = true
**Description:** By default, it's false so no duplicate releases are downloaded. Set it to true if you want to download the same release if it's re-announced or announced by multiple trackers.

##### unique-torrent-names
> **Type:** Boolean
**Default:** false
**Example:** unique-torrent-names = true
**Description:** If true, all saved torrent filenames are unique (the site name is prepended to the filename). Set it to false to use the torrent release name as the filename.

##### download-retry-time-seconds
> **Type:** Integer
**Default:** 300
**Example:** download-retry-time-seconds = 120
**Description:** If a download fails, autodl-irssi will try to re-download it every 3 seconds for  **download-retry-time-seconds** seconds. It will give up after **download-retry-time-seconds** and report an error.

##### path-utorrent
> **Type:** String
**Default:** nothing
**Example:** path-utorrent = /cygdrive/c/Program Files (x86)/uTorrent/uTorrent.exe
**Description:** Set it to the path of uTorrent if you're using an **upload-type** equal to **dyndir**.


## Torrent Actions
autodl-irssi can save a torrent file to a watch directory, upload it to uTorrent webui, upload it to an FTP server, execute a program or use uTorrent to save it to a dynamic directory name that depends on the current torrent.

By default, the global action set in your **[options]** header is used, but you can override it in any filter by placing a new **upload-type** in the **[filter]** header.

### rTorrent
```
upload-type = rtorrent
rt-dir = /home/YOURNAME/downloads/$(Month)$(Day)/$(Tracker)
rt-commands = print="Added: $(TorrentName)"; print="Hello, world!"
rt-label = $(Tracker)
#rt-ratio-group = rat_3
#rt-channel = thr_2
rt-priority = high
#rt-ignore-scheduler = true
#rt-dont-add-name = false
```

##### rt-dir
> The destination directory. The torrent data will be saved here. Supports [macros](#macros).

##### rt-commands
> Execute the given rTorrent commands when loading the torrent file.

##### rt-label
> Set a ruTorrent label.

##### rt-ratio-group
> Set a ruTorrent ratio group. Valid names are rat_0, rat_1, ..., rat_7. You must have the ratio ruTorrent plugin installed.

##### rt-channel
> Set a ruTorrent channel. Valid names are thr_0, thr_1, ..., thr_9. You must have the throttle ruTorrent plugin installed.

##### rt-priority
> Set the torrent priority. Valid values are 0, dont-download, 1, low, 2, normal, 3, high. If you set it to dont-download (or 0), the torrent is loaded, but not started.

##### rt-ignore-scheduler
> Set it to true to disable the ruTorrent scheduler.

##### rt-dont-add-name
> Set it to true if you don't want the torrent name to be added to the path.


### Watch Directory
```
upload-type = watchdir
upload-watch-dir = /home/myusername/mywatchdir
```

##### upload-watch-dir
> Your torrent client's watch directory. Supports [macros](#macros).

### uTorrent WebUI
```
upload-type = webui
```

_Set webui user, password, etc below the **[webui]** header!_

### FTP
```
upload-type = ftp
upload-ftp-path = /path/to/directory
```

_Set FTP user, password, etc in the **[ftp]** header!_

### Execute a Command
```
upload-type = exec
upload-command = /path/to/program
upload-args = all arguments here
```

##### upload-command
> The program or script to execute. Supports [macros](#macros).

##### upload-args
> The arguments given to the **upload-command**. Supports [macros](#macros).


### uTorrent Dynamic Directory
```
upload-type = dyndir
upload-dyndir = c:\the\windows\path\$(macro)$(macro2)\$(macro3)
```

_You need to initialize **path-utorrent** below [options] or it won't work!_

**Important:** autodl-irssi assumes that the Z: drive is mapped to your / (root) directory if you're using Wine to run uTorrent.

##### upload-dyndir
> The directory to save the torrent. Supports [macros](#macros).

## Macros

_Enclose the macro in double quotes if it's possible that the macro contains spaces._

> **$(year)** - Current year.
**$(month)** - Current month.
**$(day)** - Current day.
**$(hour)** - Current hour.
**$(minute)** - Current minute.
**$(second)** - Current second.
**$(milli)** - Current millisecond.
**$(FilterName)** - Name of matched filter.
**$(Site)** - Tracker type from the tracker file.
**$(Tracker)** - The long tracker name from the tracker file.
**$(TrackerShort)** - The short tracker name from the tracker file.
**$(TorrentPathName)** - The path to the .torrent file (unix path if you're using cygwin).
**$(WinTorrentPathName)** - The windows path to the .torrent file.
**$(InfoHash)** - The info hash of the torrent file.
**$(TYear)** - Torrent release year.
**$(Name1)**, **$(Artist)**, **$(Show)**, **$(Movie)** - Equivalent to the shows/artist value.
**$(Name2)**, **$(Album)** - Equivalent to the album value.
**$(Category)**
**$(TorrentName)**
**$(Uploader)**
**$(TorrentSize)**
**$(PreTime)**
**$(TorrentUrl)**
**$(TorrentSslUrl)**
**$(Season)**
**$(Season2)** - Two digit season number.
**$(Episode)**
**$(Episode2)** - Two digit episode number.
**$(Resolution)**
**$(Source)**
**$(Encoder)**
**$(Container)**
**$(Format)**
**$(Bitrate)**
**$(Media)**
**$(Tags)**
**$(Scene)**
**$(ReleaseGroup)**
**$(Log)**
**$(Cue)**


## Wake on LAN
It's possible to wake up the computer before uploading the torrent (uTorrent webui or FTP upload). You may need to make sure your BIOS and network card have WOL enabled.

wol-mac-address = 00:11:22:33:44:55
wol-ip-address = 12.34.56.78  (or a DNS name, eg. www.blah.com)
wol-port = 9 (defaults to 9 if you leave it blank)

**wol-mac-address** is the MAC (or hardware) address of the computer's network card. Use ifconfig /all (windows) or ifconfig -a (Linux) to find out your network card's MAC address.

If you have a router, then set **wol-ip-address** to your router's public IP address, and make sure the router forwards UDP packets to port **wol-port** (default 9) to your router's internal broadcast address (usually 192.168.0.255).
