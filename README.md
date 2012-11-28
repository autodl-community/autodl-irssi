A community fork of [autodl-irssi](http://sourceforge.net/projects/autodl-irssi/).  
autodl-irssi is licensed under the [Mozilla Public License 1.1](https://www.mozilla.org/MPL/1.1/)  
See https://github.com/autodl-irssi-community/autodl-irssi for details.

# autodl-irssi


This is an auto downloader for Irssi.

Features:
* ruTorrent plugin (optional).
* Supports your favorite tracker
* Advanced but easy to use filters. No complicated regex required, not even wildcards for TV shows and movies.
* Some of the filters: release, size, tracker, resolution, source (eg. BluRay), category, format (eg. FLAC), bitrate, and many more.
* Torrent can be saved to a watch directory, or uploaded to uTorrent webui or an FTP server.
* Option to set max downloads per day/week/month
* Torrent data folder name can use info from the torrent or current date (eg. "dated" folders)
* No broken .torrent files are ever uploaded to your client. Torrent files are verified before uploading them.
* Duplicate releases are not downloaded by default.
* Torrents are downloaded in the background so Irssi isn't blocked.
* SSL downloads can be forced.
* Automatic updates.
* Automatically connects to IRC servers and channels
* Wake on LAN

## Installation

The install script will install autodl-irssi and optionally also ruTorrent, the ruTorrent plugin and any other dependencies required to have a fully working ruTorrent install. It will ask a few questions and then install whatever you selected.

### Ubuntu and Ubuntu clones

	cd
	wget --no-check-certificate -O autodl-setup https://github.com/downloads/autodl-irssi-community/autodl-irssi/autodl-setup
	sudo sh autodl-setup

### Any other OS
Log in as root:
	su -
Then install it:

	wget --no-check-certificate -O autodl-setup https://github.com/downloads/autodl-irssi-community/autodl-irssi/autodl-setup
	sh autodl-setup


To use the autodl-irssi ruTorrent plugin, click its icon at the top of ruTorrent. It's usually the icon to the left of ruTorrent's settings icon. The icon is either a white bubble or a white down arrow inside a green square. The autodl-irssi tab will show all autodl-irssi output as long as ruTorrent is loaded.



If you don't use the ruTorrent plugin, then you may want to send all autodl-irssi output to its own window:
By default, all autodl-irssi output goes to the **(status)** window. If there's a window called **autodl**, then it will write all output to that window. Use these Irssi commands to create a new window named **autodl** and place it right after the status window (i.e., window position 2):
	First start Irssi! :D
	/window new hidden
	/window name autodl
	/window move 2
	/layout save
	/save


Since some people don't want users to have shell access, it's also possible to disable the "exec" action. Create **/etc/autodl.cfg** and add this:

	[options]
	allowed = watchdir, rtorrent

That will only enable the rtorrent and "Save to watch dir" actions. The following can be used with the **allowed** option:

rtorrent
watchdir
webui (requires uTorrent)
ftp
exec
dyndir (requires uTorrent)

It's a comma seperated list, eg.: allowed = watchdir, ftp



## Manual installation

If you can't use the installer for some reason, then try a manual install.

autodl-irssi requires Irssi compiled with Perl support.

autodl-irssi has the following Perl module dependencies:
* Archive::Zip
* Net::SSLeay
* HTML::Entities
* XML::LibXML
* Digest::SHA1
* JSON
* JSON::XS (optional)

Use your package manager to install them or use the CPAN utility. If you use CPAN, you will need a build environment already installed, eg. gcc, make, etc.

	cpan Archive::Zip Net::SSLeay HTML::Entities XML::LibXML Digest::SHA1 JSON JSON::XS

The optional ruTorrent plugin has the following PHP dependencies:
* json
* sockets
* xml

You can test for the presence of those modules by executing the following command. If you get no output then they're installed:

	for module in json xml sockets; do php -m|grep -wq $module || echo "Missing module: $module"; done

Use your package manager to install them unless they're already installed. You may need to edit your php.ini file by adding this:

	extension=sockets.so
	extension=json.so
	extension=xml.so


Don't forget to restart your web server if you make any changes to php.ini.


Installing autodl-irssi. Note: Make sure you're **not** root when you execute the following commands.

	mkdir -p ~/.irssi/scripts/autorun
	cd ~/.irssi/scripts
	wget -O autodl-irssi.zip https://github.com/downloads/autodl-irssi-community/autodl-irssi/autodl-setup
	unzip -o autodl-irssi.zip
	rm autodl-irssi.zip
	cp autodl-irssi.pl autorun/
	mkdir -p ~/.autodl
	touch ~/.autodl/autodl.cfg


The autodl-irssi startup script has been copied to the autorun directory so it will be started automatically when Irssi is started.


Installing the optional ruTorrent plugin. You may need to slightly modify the steps if you're not using Ubuntu or if ruTorrent isn't installed to /var/www/rutorrent/

	cd /var/www/rutorrent/plugins
	sudo svn co https://autodl-irssi.svn.sourceforge.net/svnroot/autodl-irssi/trunk/rutorrent/autodl-irssi
	sudo cp autodl-irssi/_conf.php autodl-irssi/conf.php
	sudo chown -R www-data:www-data autodl-irssi


This install assumes ruTorrent is not password protected. For password protected (i.e., multi-user) setup, you need to copy conf.php to the user plugins directory and not to the plugin directory. Eg. you need to copy it to a path similar to /var/www/rutorrent/conf/users/YOUR-USER-NAME/plugins/autodl-irssi

Edit conf.php with a text editor and add your port number and password. The port number should be a random number between 1024 and 65535 inclusive. The file should look something like this afterwards:

	<?php
	$autodlPort = 12345;
	$autodlPassword = "secretpass";
	?>


Open ~/.autodl/autodl2.cfg with a text editor and add this to the file:
	[options]
	gui-server-port = 12345
	gui-server-password = secretpass


If you start more than one Irssi process, make sure each Irssi process uses a unique port number! It won't work if they all use the same port number.


## The autodl.cfg file

NOTE: If you're using the ruTorrent plugin, you don't need to read this! :D

All filters and other options are read from ~/.autodl/autodl.cfg. If you use non-ASCII characters, be sure to set the encoding (or character coding) to UTF-8 before saving it. The file will be automatically re-read whenever you make any modifications to it when autodl-irssi is running.

If you have used the ChatZilla auto downloader, I wrote a program that will convert autodl-cz's options into a format understood by autodl-irssi. See **Using autodl-cz's options** somewhere near the bottom.

Here's an example autodl.cfg file you can modify:
```
# Lines beginning with a '#' character are ignored (i.e., they're comments!)

# TV-shows/movies template: (note that wildcards aren't necessary in the **shows** filter option!)
[filter TV SHOW MOVIE FILTER TEMPLATE]
shows = The Simpsons, Other show, 3rd Show, Some movie, Movie #2
max-size = 2GB
#seasons = 3-8
#episodes = 0-99
resolutions = SD, 720p
sources = HDTV, DVDRip, BluRay
encoders = xvid, x264
#years = 2008-2012, 1950
#match-sites =

# Music template:
[filter MUSIC FILTER TEMPLATE]
match-sites = what, waffles
min-size = 30MB
max-size = 1GB
years = 1950-1969, 2000, 2009-2099
#shows = ArtistOrGroup #1, ArtistOrGroup #2, etc
#albums = Album #1, Album #2, etc
formats = MP3, FLAC
bitrates = v0 (vbr), lossless
media = CD
#tags = hip hop, tag #2, tag #3
#tags-any = true
#except-tags = hip hop, tag #2, tag #3
#except-tags-any = false
#scene =
#log =
#cue =

# Random scene releases:
[filter RANDOM SCENE RELEASE FILTER TEMPLATE]
match-releases = the?simpsons*, american?dad*, blah*
except-releases = *-LOL, *-crapgroup, crap.release*
#match-sites =
#except-sites =
#min-size = 10MB
max-size = 500MB
#max-pretime = 3 secs
#match-uploaders =
#except-uploaders =

# All releases from a certain category:
[filter CATEGORY FILTER TEMPLATE]
match-categories = *MP3*, *XVID*
#except-categories = *XXX*
#match-releases =
#except-releases =
#match-sites =
#except-sites =
#min-size =
max-size = 10GB

[filter rtorrent stuff]
match-releases = Some.Random.Release-GRP
# ... etc
upload-type = rtorrent
rt-dir = /home/YOURNAME/downloads/$(Month)$(Day)/$(Tracker)
#rt-commands = print="Added: $(TorrentName)"; print="Hello, world!"
rt-label = $(Tracker)
#rt-ratio-group = rat_3
#rt-channel = thr_2
rt-priority = high
#rt-ignore-scheduler = true
#rt-dont-add-name = false

[options]
max-saved-releases = 1000
save-download-history = true
download-duplicates = false
upload-type = watchdir
#upload-type = webui
#upload-type = ftp
upload-watch-dir = /home/username/watchdir
upload-ftp-path = /

[webui]
user = 
password = 
hostname = 
port = 
ssl = 

[ftp]
user = 
password = 
hostname = 
port = 

[tracker scc]
authkey =
```
All lines starting with the # character are ignored (they're comments). Use it to disable some options.

The file contains several headers of the form **[headername]** and header options immediately below the header. The options are of the form **option-name = option-value**. If you leave out the value or option-name, then the default value will be used.

There are a few different option types:
Comma separated list. eg. **value1, value2, value3**.
List of numbers. eg. **1980-1999, 2010, 2012**
String. Any number of random characters.
Integer. Any integer.
Boolean. **false**, **off**, **no**, or **0** all mean "false". Anything else means "true".
Size. eg. **120 MB** or **4.5GB**

All option values are case-insensitive so eg. **The Simpsons** is the same thing as **the siMPSonS**.

The comma separated list type supports wildcards, where the ***** character means 0 or more characters, and the **?** character means exactly one character. Google wildcards for more information. Example, ***simpsons*** will match any text with the word simpsons in it. It means **First 0 or more characters, then "simpsons", then 0 or more characters**. Note that **simpsons*** is not the same thing, it means **First "simpsons" then 0 or more characters**, so **simpsons*** will match anything that begins with the word "simpsons" followed by any text.

### The filter header
Create one [filter] header per filter. You can optionally name the filter like **[filter MY FILTER NAME]**. All filter options are optional! If you don't use any filter options, then everything will be downloaded because your filter doesn't filter out anything.

**Name:** enabled
**Type:** Boolean
**Default:** true
**Example:** enabled = false
**Description:** Use it to disable a filter. All filters are enabled by default.

**Name:** match-releases
**Type:** Comma separated list
**Example:** match-releases = The?Simpsons*, American?Dad*
**Description:** It's compared against the torrent name, eg. **Some.release.720p.HDTV-GROUP**. If the filter should only match TV-shows or movies, it's easier to use the **shows** filter option since it doesn't require wildcards.

**Name:** except-releases
**Description:** The exact opposite of **match-releases**. If a release matches this option, then it's NOT downloaded.

**Name:** match-categories
**Type:** Comma separated list
**Example:** match-categories = *MP3*, TV/XVID
**Description:** It's compared against the torrent category.

**Name:** except-categories
**Description:** The exact opposite of **except-categories**. If a release matches this option, then it's NOT downloaded.

**Name:** match-sites
**Type:** Comma separated list
**Example:** match-sites = tracker1, tracker2, tracker3
**Description:** It's compared against the tracker. Use the full tracker name, eg. MyTracker or use one of the tracker types found in ~/.irssi/scripts/AutodlIrssi/trackers/*.tracker. Open one of the files and locate the **type="XYZ"** line. Use the value inside the quotes, eg. **XYZ**.

**Name:** except-sites
**Description:** The exact opposite of **match-sites**. If a release matches this option, then it's NOT downloaded.

**Name:** min-size
**Type:** Size
**Example:** min-size = 200MB
**Default:** 0
**Description:** Used to filter out too small torrents.

**Name:** max-size
**Type:** Size
**Example:** max-size = 2.5GB
**Default:** any size is allowed
**Description:** Used to filter out too big torrents. I recommend everyone to always use this option so you don't accidentally download a 100GB torrent! :D Set it to a reasonable value, eg. for TV-shows, set it to about twice the size of a normal episode (just in case it's a double-episode). This will automatically filter out season packs!

**Name:** shows
**Type:** Comma separated list
**Example:** shows = The Simpsons, American Dad
**Description:** This is for TV-shows, movies and artists/groups (what.cd/waffles only). autodl-irssi will automatically extract the TV-show/movie name from a scene release name. Example, The.Simpsons.S35E24.720p.HDTV-BLAH will match a **shows** option set to **the simpsons**. You don't need wildcards at all, though it's possible to use wildcards. It's recommended to use **shows** instead of **match-releases** if all you want is for the filter to match TV-shows or movies. what.cd and waffles: this will match against the artist/group.

**Name:** seasons
**Type:** List of numbers
**Example:** seasons = 1, 3, 5-10
**Description:** This is for TV-shows only. Unless the release matches one of the seasons, it's not downloaded.

**Name:** episodes
**Type:** List of numbers
**Example:** episodes = 1, 3, 5-10
**Description:** This is for TV-shows only. Unless the release matches one of the episodes, it's not downloaded.

**Name:** resolutions
**Type:** Comma separated list
**Example:** resolutions = SD, 720p, 1080p
**Description:** This is for TV-shows and movies only. Unless the release matches one of the resolutions, it's not downloaded. Valid resolutions are one or more of the following: **SD**, **480i**, **480p**, **576p**, **720p**, **810p**, **1080i**, **1080p**.

**Name:** sources
**Type:** Comma separated list
**Example:** sources = HDTV, DVDRip, BluRay
**Description:** This is for TV-shows and movies only. Unless the release matches one of the sources, it's not downloaded. Valid sources are one or more of the following: **DSR**, **PDTV**, **HDTV**, **HR.PDTV**, **HR.HDTV**, **DVDRip**, **DVDScr**, **BDr**, **BD5**, **BD9**, **BDRip**, **BRRip**, **DVDR**, **MDVDR**, **HDDVD**, **HDDVDRip**, **BluRay**, **WEB-DL**, **TVRip**, **CAM**, **R5**, **TELESYNC**, **TS**, **TELECINE**, **TC**. **TELESYNC** and **TS** are synonyms (you don't need both). Same for **TELECINE** and **TC**.

**Name:** encoders
**Type:** Comma separated list
**Example:** encoders = x264, xvid
**Description:** If you don't want windows WMV files, this option could be useful. :) Valid encoders are: **XviD**, **DivX**, **x264**, **h.264** (or **h264**), **mpeg2** (or **mpeg-2**), **VC-1** (or **VC1**), **WMV**.

**Name:** years
**Type:** List of numbers
**Example:** years = 1999, 2005-2010
**Description:** Not all releases have a year in the torrent name, but if it does, you can use it to filter out too old or too new releases.

**Name:** albums
**Type:** Comma separated list
**Example:** albums = Some album, Some other album, yet another one
**Description:** what.cd/waffles only.

**Name:** formats
**Type:** Comma separated list
**Example:** formats = MP3, FLAC
**Description:** what.cd/waffles only. List the formats you want. Valid formats are: **MP3**, **FLAC**, **Ogg**, **AAC**, **AC3**, **DTS**.

**Name:** bitrates
**Type:** Comma separated list
**Example:** bitrates = 192, V0 (vbr), lossless
**Description:** what.cd/waffles only. List the bitrates you want. Some example values: **192**, **320**, **APS (VBR)**, **V2 (VBR)**, **V1 (VBR)**, **APX (VBR)**, **V0 (VBR)**, **q8.x (VBR)**, **Lossless**, **24bit Lossless**, **Other**.

**Name:** media
**Type:** Comma separated list
**Example:** media = CD, WEB
**Description:** what.cd/waffles only. List the media you want. Valid media are: **CD**, **DVD**, **Vinyl**, **Soundboard**, **SACD**, **DAT**, **Cassette**, **WEB**, **Other**.

**Name:** tags
**Type:** Comma separated list
**Example:** tags = hip hop, rock
**Description:** what.cd/waffles only. Unless at least one of your tags matches the release's tags, it's not downloaded. See also **except-tags** and **tags-any**.

**Name:** except-tags
**Type:** Comma separated list
**Example:** except-tags = hip hop, rock
**Description:** what.cd/waffles only. Same as **tags** except if it matches any/all of these, it's not downloaded. See also **tags** and **except-tags-any**.

**Name:** tags-any
**Type:** Boolean
**Default:** true
**Example:** tags-any = false
**Description:** what.cd/waffles only. Decides how to match the **tags** option, ie., if any or all of the tags must match.

**Name:** except-tags-any
**Type:** Boolean
**Default:** true
**Example:** except-tags-any = true
**Description:** what.cd/waffles only. Decides how to match the **except-tags** option, ie., if any or all of the tags must match.

**Name:** scene
**Type:** Boolean
**Example:** scene = true
**Description:** what.cd/waffles, and a few others. Some sites mark a release as scene or non-scene. Set it to true if you want only scene releases, false if you only want non-scene releases, or don't use this option if you don't care.

**Name:** log
**Type:** Boolean
**Example:** log = true
**Description:** what.cd/waffles. Set it to true if you only want releases with a log file, false if you don't want releases with log files, or don't use this option if you don't care.

**Name:** cue
**Type:** Boolean
**Example:** cue = true
**Description:** what.cd. Set it to true if you only want releases with a cue file, false if you don't want releases with cue files, or don't use this option if you don't care.

**Name:** match-uploaders
**Type:** Comma separated list
**Example:** match-uploaders = uploader1, uploader2
**Description:** Use it to only download from certain uploaders.

**Name:** except-uploaders
**Description:** The exact opposite of **match-uploaders**. If a release matches this option, then it's NOT downloaded.

**Name:** max-pretime
**Type:** time-since string
**Example:** max-pretime = 2 mins 3 secs
**Description:** Some sites announce the pretime of the release. Use this to filter out old releases.

**Name:** max-downloads
**Type:** Integer
**Example:** max-downloads = 15
**Description:** Download no more than this number of torrents per week/month (see **max-downloads-per**). Remove the filter option or set it to a negative number to disable it.

**Name:** max-downloads-per
**Type:** String
**Example:** max-downloads-per = week
**Description:** Valid values are **day**, **week**, and **month**. See **max-downloads**.

### The options header
These options change the behavior of autodl-irssi. Place these options below the **[options]** header.

**Name:** rt-address
**Type:** string
**Default:** Whatever is found in ~/.rtorrent.rc
**Example:** rt-address = 127.0.0.1:5000
**Description:** If you use the 'rtorrent' action (**upload-method**), then you must initialize this to your rtorrent's SCGI address. It can be ip:port (eg. 127.0.0.1:5000) or /path/to/socket. **NOTE:** This option can only be set in autodl2.cfg, **not** autodl.cfg.


**Name:** update-check
**Type:** string
**Default:** ask
**Example:** update-check = auto
**Description:** autodl-irssi can auto update itself. Valid values are **ask**, **auto**, and **disabled**. **ask** will print a message when there's a new version. **auto** will automatically update it when there's a new version. **disabled** won't do a thing when there's a new update.

**Name:** max-saved-releases
**Type:** Integer greater than or equal to 0.
**Default:** 1000
**Example:** max-saved-releases = 200
**Description:** autodl-irssi will remember the last **max-saved-releases** releases you have downloaded so it won't re-download the same file again. Only useful if **save-download-history** is enabled.

**Name:** save-download-history
**Type:** Boolean
**Default:** true
**Example:** save-download-history = true
**Description:** Set it to false to disable writing the last N (= **max-saved-releases**) downloaded releases to ~/.autodl/DownloadHistory.txt.

**Name:** download-duplicates
**Type:** Boolean
**Default:** false
**Example:** download-duplicates = true
**Description:** By default, it's false so no duplicate releases are downloaded. Set it to true if you want to download the same release again if it's re-announced.

**Name:** unique-torrent-names
**Type:** Boolean
**Default:** false
**Example:** unique-torrent-names = true
**Description:** If true, all saved torrent filenames are unique (the site name is prepended to the filename). Set it to false to use the torrent release name as the filename.

**Name:** download-retry-time-seconds
**Type:** Integer
**Default:** 300
**Example:** download-retry-time-seconds = 120
**Description:** If a download fails, autodl-irssi will try to re-download it after waiting a little while. If it still can't download it after **download-retry-time-seconds** seconds, it will give up and report an error.

**Name:** path-utorrent
**Type:** String
**Default:** nothing
**Example:** path-utorrent = /cygdrive/c/Program Files (x86)/uTorrent/uTorrent.exe
**Description:** Set it to the path of uTorrent if you're using an **upload-type** equal to **dyndir**.


### Sending Wake on LAN (WOL)
It's possible to wake up the computer before uploading the torrent (uTorrent webui or FTP upload). You may need to make sure your BIOS and network card have WOL enabled.

wol-mac-address = 00:11:22:33:44:55
wol-ip-address = 12.34.56.78  (or a DNS name, eg. www.blah.com)
wol-port = 9 (defaults to 9 if you leave it blank)

**wol-mac-address** is the MAC (or hardware) address of the computer's network card. Use ifconfig /all (windows) or ifconfig -a (Linux) to find out your network card's MAC address.

If you have a router, then set **wol-ip-address** to your router's public IP address, and make sure the router forwards UDP packets to port **wol-port** (default 9) to your router's internal broadcast address (usually 192.168.0.255).


### Torrent action options
autodl-irssi can save a torrent file to a watch directory, upload it to uTorrent webui, upload it to an FTP server, execute a program or use uTorrent to save it to a dynamic directory name that depends on the current torrent.

There's a global action option in the [options] header and a local action option in each filter. By default, the global action option is used but you can override it in any filter by placing a new **upload-type** below your [filter] header.

**rtorrent only:**
	upload-type = rtorrent
	rt-dir = /home/YOURNAME/downloads/$(Month)$(Day)/$(Tracker)
	rt-commands = print="Added: $(TorrentName)"; print="Hello, world!"
	rt-label = $(Tracker)
	#rt-ratio-group = rat_3
	#rt-channel = thr_2
	rt-priority = high
	#rt-ignore-scheduler = true
	#rt-dont-add-name = false

**rt-dir** is the destination directory. The torrent data will be saved here. Macros can be used.
**rt-commands** can be used to execute some rtorrent commands when loading the torrent file. It's for advanced users only.
**rt-label** is used to set a ruTorrent label.
**rt-ratio-group** is used to set a ruTorrent ratio group. Valid names are rat_0, rat_1, ..., rat_7. You must have the ratio ruTorrent plugin installed.
**rt-channel** is used to set a ruTorrent channel. Valid names are thr_0, thr_1, ..., thr_9. You must have the throttle ruTorrent plugin installed.
**rt-priority** sets the torrent priority. Valid values are 0, dont-download, 1, low, 2, normal, 3, high. If you set it to dont-download (or 0), the torrent is loaded, but not started.
**rt-ignore-scheduler**: set it to true to disable the ruTorrent scheduler.
**rt-dont-add-name**: set it to true if you don't want the torrent name to be added to the path.


**Save torrent to a watch directory:**
	upload-type = watchdir
	upload-watch-dir = /home/myusername/mywatchdir

**Upload torrent to uTorrent webui:**
Don't forget to initialize webui user, password, etc below the [webui] header!
	upload-type = webui

**Upload torrent to an FTP server:**
Don't forget to initialize FTP user, password, etc below the [ftp] header!
upload-type = ftp
upload-ftp-path = /ftp/server/path

**Execute a program:**
	upload-type = exec
	upload-command = /path/to/program
	upload-args = all arguments here

Both **upload-command** and **upload-args** support macros. See Macros below for an explanation of all available macros. Just remember to enclose the macro in double quotes if it's possible that the macro contains spaces. Example: **upload-args = --torrent "$(TorrentPathName)" --category $(Category)**


**Save torrent data to a dynamic directory using uTorrent:**
You need to initialize **path-utorrent** below [options] or it won't work!

	upload-type = dyndir
	upload-dyndir = c:\the\windows\path\$(macro)$(macro2)\$(macro3)

Important: autodl-irssi assumes that the Z: drive is mapped to your / (root) directory if you're using Wine to run uTorrent.

**upload-dyndir** supports macros. See Macros below for an explanation of all available macros. You can use macros to create a directory based on current day and month. Some examples:

**upload-dyndir = c:\mydownloads\$(year)-$(month)-$(day)** will save the torrent data below a directory containing the current year, month and day. Eg. **c:\mydownloads\2010-10-28** if 2010-10-28 happened to be the current day.

**upload-dyndir = c:\mydownloads\$(month)$(day)\$(trackershort)\$(category)** will save the data to a directory based on current month, day, tracker name, and torrent category.

### The webui header
	[webui]
	user =
	password =
	hostname =
	port =
	ssl =
user is user name, password is your password, hostname is the IP-address (uTorrent only wants IP-addresses), and port is the webui port. Set **ssl = true** to enable encrypted uploads or false to use normal non-encrypted uploads. Read here on how to enable HTTPS webui: http://www.utorrent.com/documentation/webui

### The FTP header
	[ftp]
	user =
	password =
	hostname =
	port =
user is user name, password is your password, hostname is the hostname/IP-address, and port is the FTP port.


### The IRC options header
	auto-connect = true
Set it to true to enable auto connecting to IRC servers and channels.

	user-name =
	real-name =
IRC user name and real name. Leave blank if we should use Irssi's settings.

	output-server =
	output-channel =
Send all autodl-irssi output to the specified IRC server and channel. Make sure you've setup autodl-irssi to auto connect to the IRC server and channel.


### The tracker header
Your trackers require that you authenticate before letting you download a torrent file. Use the tracker headers to set the required options so downloads work.

A tracker header looks like **[tracker TYPE]** where **TYPE** is the tracker type. This is the exact same type that you find in the **~/.irssi/scripts/AutodlIrssi/trackers/*.tracker** files. Open one of the files with a text editor and locate the **type="XYZ"** line. Use the value inside the quotes, eg. **XYZ**. Example: **[tracker XYZ]**. Case matters so XYZ is different from xyz.

Some trackers require a **passkey**, others an **authkey**, or a **cookie**, etc. To quickly find out which one your tracker needs, just add **[tracker TYPE]** (with no options below it) to autodl.cfg and wait 1-2 seconds (start Irssi if necessary). It will report the missing options, eg.: **ERROR: /home/YOURNAME/.autodl/autodl.cfg: line 123: TRACKER-TYPE: Missing option(s): passkey, uid**. Here it's saying that you forgot to add the options **passkey = XXX** and **uid = YYY**. Add them below the tracker header.

Some common tracker options and how to get them:

**cookie**: Go to your tracker's home page, then type **javascript:document.innerHTML=document.cookie** in the address bar and press enter. You should now see your cookie. If all you see is PHPSESSID=XXXXX, then you'll have to manually get the cookie using FireFox: Edit -> Preferences -> Privacy tab -> Show Cookies. It's usually just **uid=XXX; pass=YYY**. Separate each key=value pair with a semicolon.

**passkey**: First check a torrent download link if it contains it. If not you can usually find it in the generated RSS-feed URL, which you probably can generate @ yourtracker.com/getrss.php . passkeys are usually exactly 32 characters long. The passkey can also sometimes be found in your profile (click your name).

**authkey**: See **passkey** above. For gazelle sites, it's part of the torrent download link.

**torrent_pass**: For gazelle sites, it's part of the torrent download link.

**uid**: Click your username and you should see the id=XXX in the address bar. That's your user id, or uid.

	[tracker TYPE]
	#enabled =
	#force-ssl =
	#upload-delay-secs =
	#cookie =
	#passkey =
	#etc ...

**enabled** is optional and defaults to true. Set it to false to disable the tracker.
**force-ssl** is optional and can be set to true to force encrypted torrent downloads. Not all trackers support HTTPS downloads. Leave it blank for the default value (which is HTTP or HTTPS).
**upload-delay-secs** is optional and is the number of seconds autodl-irssi should wait before uploading/saving the torrent. Default is 0 (no wait). This option isn't needed 99.999% of the time.



### Macros

Current date and time: **$(year)**, **$(month)**, **$(day)**, **$(hour)**, **$(minute)**, **$(second)**, **$(milli)**
**$(TYear)** is the year of the torrent release, not current year.
**$(Artist)**, **$(Show)**, **$(Movie)**, **$(Name1)** all mean the same thing.
**$(Album)**, **$(Name2)** both mean the same thing.
**$(Site)** is tracker URL.
**$(Tracker)** is long tracker name.
**$(TrackerShort)** is short tracker name.
**$(TorrentPathName)** is the path to the .torrent file (unix path if you're using cygwin).
**$(WinTorrentPathName)** is the windows path to the .torrent file.
**$(InfoHash)** This is the "info hash" of the torrent file.

The rest are possibly self explanatory: **$(Category)**, **$(TorrentName)**, **$(Uploader)**, **$(TorrentSize)**, **$(PreTime)**, **$(TorrentUrl)**, **$(TorrentSslUrl)**, **$(Season)**, **$(Episode)**, **$(Resolution)**, **$(Source)**, **$(Encoder)**, **$(Format)**, **$(Bitrate)**, **$(Media)**, **$(Tags)**, **$(Scene)**, **$(Log)**, **$(Cue)**

**$(Season2)** and **$(Episode2)** are two-digit season and episode numbers.





## Using autodl-cz's options
This part explains how to re-use autodl-cz's options.

You need the XML::LibXSLT Perl module to run this script. Some other Perl modules are also required but they're installed by the installer.

It's important that you are using at least version 2.03 of autodl-cz! After upgrading it, run it once and go to Auto Downloader -> Preferences. Press OK and it will save all options in the 2.03 (or later) format. Failure to do this may result in a pretty useless autodl.cfg file.

Start ChatZilla and type **/pref profilePath** and press enter. Copy your profilePath, which is something like **/home/YOURNAME/.mozilla/firefox/XXXXXXXXX.default/chatzilla**, and append **/autodl/settings/autodl.xml** so you get something like **/home/YOURNAME/.mozilla/firefox/XXXXXXXXX.default/chatzilla/scripts/autodl/settings/autodl.xml**. That's the path to your autodl-cz's options file. Now type this in your terminal (add your path below):

	mkdir -p ~/.autodl
	wget http://sourceforge.net/projects/autodl-irssi/files/convertxml.pl/download
	perl convertxml.pl /home/YOURNAME/.mozilla/firefox/XXXXXXXXX.default/chatzilla/scripts/autodl/settings/autodl.xml > ~/.autodl/autodl.cfg
