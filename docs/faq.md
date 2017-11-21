### How do I get a new tracker added to autodl-irssi?

**First, check with tracker staff to get permission; some trackers don't want people autodownloading.**

If you know how to create a new tracker file or edit an existing tracker file to suit your needs, you can submit a Pull Request to the [trackers repository](https://github.com/autodl-community/autodl-trackers) following the [contributing guidelines](https://github.com/autodl-community/autodl-trackers/blob/master/CONTRIBUTING.md#submitting-code). If you need it to be created by a member of autodl-community, [submit an issue](https://github.com/autodl-community/autodl-trackers/blob/master/CONTRIBUTING.md#submitting-an-issue) to the [trackers repository](https://github.com/autodl-community/autodl-trackers) or come to the IRC channel in the footer with the following information:

* Tracker name
* Tracker abbreviation (if applicable)
* Tracker IRC server address
* Tracker IRC announce channel
* Tracker IRC announcer name
* A decent size sampling of announces from the announce channel (at least 5-10)

Preferably, this information should be provided using a pastebin site. More information may be requested if necessary.

### What's this ``Could not connect (111)`` error?

``Error downloading files. Make sure autodl-irssi is started and configured properly (eg. password, port number): Error getting files listing: Error: Could not connect: (111) Connection refused``

This is an error that occurs in the ruTorrent plugin when it can't communicate with autodl-irssi. This could be for a number of reasons:

* irssi may not be running
* autodl-irssi may not be enabled in irssi
* Multiple instances of irssi with autodl-irssi enabled could be running
* gui-server-port and gui-server-password settings may not be set in your autodl.cfg file
* You may be using a seedbox from Feral Hosting; follow [their instructions](https://www.feralhosting.com/faq/view?question=142) to get it working

### What's this error about bare wildcards?

``_____ is set to bare wildcard. This is unnecessary and unsupported by some options.``

Many people believe they need to set a filter option to a bare asterisk to grab everything based on that filter option. If that were true, they would have to set ALL filter options to a bare asterisk. However, a filter in autodl-irssi, when enabled, matches everything until you set filter options to limit (aka filter) the results. Also, autodl-irssi supports using wildcards in only one type of option, [comma separated lists](https://github.com/autodl-community/autodl-irssi/wiki/Basic-Configuration#formatting). This mistaken belief can cause people to use bare asterisks in options that don't even support it.

**TL/DR** If you're not limiting/filtering by an option, you don't need to set it to anything.
