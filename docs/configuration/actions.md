autodl-irssi can save a torrent file to a watch directory, upload it to uTorrent webui, upload it to an FTP server, execute a program or use uTorrent to save it to a dynamic directory name that depends on the current torrent.

By default, the global action set in your **[options]** header is used, but you can override it in any filter by placing a new **upload-type** in the **[filter]** header.

### Test

```
upload-type = test
```

Take no action after matching an announce. This is the default action.

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

#### rt-dir

> The destination directory. The torrent data will be saved here. Supports [macros](#macros).

#### rt-commands

> Execute the given rTorrent commands when loading the torrent file.

#### rt-label

> Set a ruTorrent label.

#### rt-ratio-group

> Set a ruTorrent ratio group. Valid names are rat_0, rat_1, ..., rat_7. You must have the ratio ruTorrent plugin installed.

#### rt-channel

> Set a ruTorrent channel. Valid names are thr_0, thr_1, ..., thr_9. You must have the throttle ruTorrent plugin installed.

#### rt-priority

> Set the torrent priority. Valid values are 0, dont-download, 1, low, 2, normal, 3, high. If you set it to dont-download (or 0), the torrent is loaded, but not started.

#### rt-ignore-scheduler

> Set it to true to disable the ruTorrent scheduler.

#### rt-dont-add-name

> Set it to true if you don't want the torrent name to be added to the path.


### Watch Directory

```
upload-type = watchdir
upload-watch-dir = /home/myusername/mywatchdir
```

#### upload-watch-dir

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

#### upload-command

> The program or script to execute. Supports [macros](#macros).

#### upload-args

> The arguments given to the **upload-command**. Supports [macros](#macros).


### uTorrent Dynamic Directory

```
upload-type = dyndir
upload-dyndir = c:\the\windows\path\$(macro)$(macro2)\$(macro3)
```

_You need to initialize **path-utorrent** below [options] or it won't work!_

**Important:** autodl-irssi assumes that the Z: drive is mapped to your / (root) directory if you're using Wine to run uTorrent.

#### upload-dyndir

> The directory to save the torrent. Supports [macros](#macros).

## Macros

_Enclose the macro in double quotes if it's possible that the macro contains spaces._

> **$(year)** - Current year.
> **$(month)** - Current month.
> **$(day)** - Current day.
> **$(hour)** - Current hour.
> **$(minute)** - Current minute.
> **$(second)** - Current second.
> **$(milli)** - Current millisecond.
> **$(FilterName)** - Name of matched filter.
> **$(Site)** - Tracker type from the tracker file.
> **$(Tracker)** - The long tracker name from the tracker file.
> **$(TrackerShort)** - The short tracker name from the tracker file.
> **$(TorrentPathName)** - The path to the .torrent file (unix path if you're using cygwin).
> **$(WinTorrentPathName)** - The windows path to the .torrent file.
> **$(InfoHash)** - The info hash of the torrent file.
> **$(InfoName)** - The name from the info section of the torrent file.
> **$(TYear)** - Torrent release year.
> **$(Name1)**, **$(Artist)**, **$(Show)**, **$(Movie)** - Equivalent to the shows/artist value.
> **$(Name2)**, **$(Album)** - Equivalent to the album value.
> **$(Category)**
> **$(TorrentName)**
> **$(Uploader)**
> **$(TorrentSize)**
> **$(PreTime)**
> **$(TorrentUrl)**
> **$(TorrentSslUrl)**
> **$(Season)**
> **$(Season2)** - Two digit season number.
> **$(Episode)**
> **$(Episode2)** - Two digit episode number.
> **$(Resolution)**
> **$(Source)**
> **$(Encoder)**
> **$(Container)**
> **$(Format)**
> **$(Bitrate)**
> **$(Media)**
> **$(Tags)**
> **$(Scene)**
> **$(ReleaseGroup)**
> **$(Log)**
> **$(Cue)**
