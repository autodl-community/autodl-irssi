Create one [filter] header per filter like **[filter MY FILTER NAME]**. All filter options are optional! If you don't use any filter options, then everything will be downloaded because your filter doesn't filter out anything.

**Note:** Not all filter options are supported on all trackers.


## General

#### enabled
> **Type:** Boolean
**Default:** true
**Example:** enabled = false
**Description:** Use it to disable a filter. All filters are enabled by default.

#### priority
> **Type:** Integer
**Default:** 0
**Example:** priority = 10
**Description:** Use it to determine the order by which filters are checked. Negative numbers are allowed.

#### match-sites
> **Type:** Comma separated list
**Example:** match-sites = tracker1, tracker2, tracker3
**Description:** It's compared against the tracker. Use the full tracker name, eg. MyTracker or use one of the tracker types found in ~/.irssi/scripts/AutodlIrssi/trackers/*.tracker. Open one of the files and locate the **type="XYZ"** line. Use the value inside the quotes, eg. **XYZ**.

#### except-sites
> **Description:** The exact opposite of **match-sites**. If a release matches this option, then it's NOT downloaded.

#### min-size
> **Type:** Size
**Example:** min-size = 200MB
**Default:** 0
**Description:** Used to filter out too small torrents.

#### max-size
> **Type:** Size
**Example:** max-size = 2.5GB
**Default:** any size is allowed
**Description:** Used to filter out too big torrents. Set it to a reasonable value, eg. for TV-shows, set it to about twice the size of a normal episode (just in case it's a double-episode).

#### upload-delay-secs
> **Type:** Integer
**Default:** 0 (no wait)
**Example:** upload-delay-secs = 10
**Description:** The number of seconds autodl-irssi should wait before uploading/saving the torrent.

#### max-downloads
> **Type:** Integer
**Example:** max-downloads = 15
**Description:** Download no more than this number of torrents per week/month (see **max-downloads-per**). Remove the filter option or set it to a negative number to disable it.

#### max-downloads-per
> **Type:** String
**Example:** max-downloads-per = week
**Description:** Valid values are **day**, **week**, and **month**. See **max-downloads**.

#### download-duplicates
> **Type:** Boolean
**Default:** false
**Example:** download-duplicates = true
**Description:** By default, it's false so no duplicate releases are downloaded. Set it to true if you want to download the same release if it's re-announced or announced by multiple trackers.


## P2P

#### match-releases
> **Type:** Comma separated list
**Example:** match-releases = The?Simpsons*, American?Dad*
**Description:** It's compared against the torrent name, eg. **Some.release.720p.HDTV-GROUP**. If the filter should only match TV-shows or movies, it's easier to use the **shows** filter option since it doesn't require wildcards.

#### except-releases
> **Description:** The exact opposite of **match-releases**. If a release matches this option, then it's NOT downloaded.

#### use-regex
> **Type:** Boolean
**Default:** false
**Description:** Changes match/except-releases filter options to use regex instead of wildcard syntax globally. This can also be set globally in the options header.

#### match-release-groups
> **Type:** Comma separated list
**Description:** Unless the release matches one of the release groups, it's not downloaded.

#### except-release-groups
> **Type:** Comma separated list
**Description:** Opposite of match-release-groups. If the release matches one of the release gorups, it's not downloaded.

#### max-pretime
> **Type:** time-since string
**Example:** max-pretime = 2 mins 3 secs
**Description:** Some sites announce the pretime of the release. Use this to filter out old releases.

#### scene
> **Type:** Boolean
**Example:** scene = true
**Description:** Some sites mark a release as scene or non-scene. Set it to true if you want only scene releases, false if you only want non-scene releases, or don't use this option if you don't care.

#### origins
> **Type:** Comma separated list
**Example:** origins = P2P, Internal
**Description:** Some trackers set the origin of a release in a more fine-grained manner than scene/non-scene.

#### freeleech
> **Type:** Boolean
**Example:** freeleech = true
**Description:** Only supported on a few trackers. Set to true if you only want to download freeleech releases. Set to false if you only want non-freeleech releases. Don't set if you don't care.

#### freeleech-percents
> **Type:** Number list
**Example:** freeleech-percents = 50,75
**Description:** Some trackers have multiple levels of freeleech. Set a Number list representing the percentages (without the % sign) of the releases you want to download.


## TV/Movies

#### shows
> **Type:** Comma separated list
**Example:** shows = The Simpsons, American Dad
**Description:** This is for TV-shows and movies. autodl-irssi will automatically extract the TV-show/movie name from a scene release name. Example, The.Simpsons.S35E24.720p.HDTV-BLAH will match a **shows** option set to **the simpsons**. You don't need wildcards at all, though it's possible to use wildcards. It's recommended to use **shows** instead of **match-releases** if all you want is for the filter to match TV-shows or movies.

#### seasons
> **Type:** Number list
**Example:** seasons = 1, 3, 5-10
**Description:** This is for TV-shows only. Unless the release matches one of the seasons, it's not downloaded.

#### episodes
> **Type:** Number list
**Example:** episodes = 1, 3, 5-10
**Description:** This is for TV-shows only. Unless the release matches one of the episodes, it's not downloaded.

#### smart-episode
> **Type:** Boolean
**Default:** false
**Example:** smart-episode = true
**Description:** Set to true to prevent downloading earlier episodes than your latest download. This option is set per filter, not per show, so it only makes sense to set one show per filter.

#### resolutions
> **Type:** Comma separated list
**Example:** resolutions = SD, 720p, 1080p
**Description:** This is for TV-shows and movies only. Unless the release matches one of the resolutions, it's not downloaded. Valid resolutions are one or more of the following: **SD**, **480i**, **480p**, **576p**, **720p**, **810p**, **1080i**, **1080p**.

#### encoders
> **Type:** Comma separated list
**Example:** encoders = x264, xvid
**Description:** If you don't want windows WMV files, this option could be useful. :) Valid encoders are: **XviD**, **DivX**, **x264**, **h.264** (or **h264**), **mpeg2** (or **mpeg-2**), **VC-1** (or **VC1**), **WMV**, **Remux**, **h.264 Remux** (or **h264 Remux**), **VC-1 Remux** (or **VC1 Remux**).

#### sources
> **Type:** Comma separated list
**Example:** sources = HDTV, DVDRip, BluRay
**Description:** This is for TV-shows and movies only. Unless the release matches one of the sources, it's not downloaded. Valid sources are one or more of the following: **DSR**, **PDTV**, **HDTV**, **HR.PDTV**, **HR.HDTV**, **DVDRip**, **DVDScr**, **BDr**, **BD5**, **BD9**, **BDRip**, **BRRip**, **DVDR**, **MDVDR**, **HDDVD**, **HDDVDRip**, **BluRay**, **WEB-DL**, **TVRip**, **CAM**, **R5**, **TELESYNC**, **TS**, **TELECINE**, **TC**. **TELESYNC** and **TS** are synonyms (you don't need both). Same for **TELECINE** and **TC**.

#### containers
> **Type:** Comma separated list
**Example:** containers = mkv, mp4
**Description:** Unless the release matches one of the containers, it's not downloaded.

#### years
> **Type:** Number list
**Example:** years = 1999, 2005-2010
**Description:** Not all releases have a year in the torrent name, but if it does, you can use it to filter out too old or too new releases.

## Music

#### years
> **Type:** Number list
**Example:** years = 1999, 2005-2010
**Description:** Not all releases have a year in the torrent name, but if it does, you can use it to filter out too old or too new releases.

#### artists
> **Type:** Comma separated list
**Example:** shows = Muse, Modest Mouse
**Description:** This is for artists/groups. You don't need wildcards at all, though it's possible to use wildcards.

#### albums
> **Type:** Comma separated list
**Example:** albums = Some album, Some other album, yet another one
**Description:**

#### match-release-types
> **Type:** Comma separated list
**Example:** match-release-types = Album,Single,EP
**Description:** Matches on the release type of the torrent.

#### except-release-types
> **Type:** Comma separated list
> **Description:** The exact opposite of **match-release-types**. When this matches, do *NOT* download the torrent.

#### formats
> **Type:** Comma separated list
**Example:** formats = MP3, FLAC
**Description:** List the formats you want. Valid formats are: **MP3**, **FLAC**, **Ogg**, **AAC**, **AC3**, **DTS**.

#### bitrates
> **Type:** Comma separated list
**Example:** bitrates = 192, V0 (vbr), lossless
**Description:** List the bitrates you want. Some example values: **192**, **320**, **APS (VBR)**, **V2 (VBR)**, **V1 (VBR)**, **APX (VBR)**, **V0 (VBR)**, **q8.x (VBR)**, **Lossless**, **24bit Lossless**, **Other**.

#### media
> **Type:** Comma separated list
**Example:** media = CD, WEB
**Description:** List the media you want. Valid media are: **CD**, **DVD**, **Vinyl**, **Soundboard**, **SACD**, **DAT**, **Cassette**, **WEB**, **Other**.

#### cue
> **Type:** Boolean
**Example:** cue = true
**Description:** what.cd. Set it to true if you only want releases with a cue file, false if you don't want releases with cue files, or don't use this option if you don't care.

#### log
> **Type:** Boolean
**Example:** log = true
**Description:** Set it to true if you only want releases with a log file, false if you don't want releases with log files, or don't use this option if you don't care.

#### log-scores
> **Type:** Number list
**Default:** Any score allowed
**Example:** log-scores = 90-95,96,98,100
**Description:** Set the log scores of the releases you want to match.


## Advanced

#### match-categories
> **Type:** Comma separated list
**Example:** match-categories = *MP3*, TV/XVID
**Description:** It's compared against the torrent category.

#### except-categories
> **Description:** The exact opposite of **match-categories**. If a release matches this option, then it's NOT downloaded.

#### match-uploaders
> **Type:** Comma separated list
**Example:** match-uploaders = uploader1, uploader2
**Description:** Use it to only download from certain uploaders.

#### except-uploaders
> **Description:** The exact opposite of **match-uploaders**. If a release matches this option, then it's NOT downloaded.

#### tags
> **Type:** Comma separated list
**Example:** tags = hip hop, rock
**Description:** Unless at least one of your tags matches the release's tags, it's not downloaded. See also **except-tags** and **tags-any**.

#### except-tags
> **Type:** Comma separated list
**Example:** except-tags = hip hop, rock
**Description:** Same as **tags** except if it matches any/all of these, it's not downloaded. See also **tags** and **except-tags-any**.

#### tags-any
> **Type:** Boolean
**Default:** true
**Example:** tags-any = false
**Description:** Decides how to match the **tags** option, ie., if any or all of the tags must match.

#### except-tags-any
> **Type:** Boolean
**Default:** true
**Example:** except-tags-any = true
**Description:** Decides how to match the **except-tags** option, ie., if any or all of the tags must match.
