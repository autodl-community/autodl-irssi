### Requirements

autodl-irssi requires irssi compiled with Perl support.

autodl-irssi has the following Perl module dependencies:
* Archive::Zip
* Net::SSLeay
* HTML::Entities
* XML::LibXML
* Digest::SHA
* JSON
* JSON::XS (optional)

Use your package manager to install them or use the CPAN utility. If you use CPAN, you will need a build environment already installed, eg. gcc, make, etc.

	cpan Archive::Zip Net::SSLeay HTML::Entities XML::LibXML Digest::SHA JSON JSON::XS

### Installation

Note: Make sure you're **not** root when you execute the following commands.

``` bash
mkdir -p ~/.irssi/scripts/autorun
cd ~/.irssi/scripts
curl -sL http://git.io/vlcND | grep -Po '(?<="browser_download_url": ")(.*-v[\d.]+.zip)' | xargs wget --quiet -O autodl-irssi.zip
unzip -o autodl-irssi.zip
rm autodl-irssi.zip
cp autodl-irssi.pl autorun/
mkdir -p ~/.autodl
touch ~/.autodl/autodl.cfg
```

The autodl-irssi startup script has been copied to the autorun directory so it will be started automatically when irssi is started.

### Post installation

#### autodl Window

By default, all autodl-irssi output goes to the **(status)** window. If you want to send all autodl-irssi output to its own window, you can create a window in irssi named **autodl**. Use these irssi commands to create a new window named **autodl** and place it right after the status window (i.e., window position 2)

	/window new hidden
	/window name autodl
	/window move 2
	/layout save
	/save

#### ruTorrent Plugin

If you want to install the ruTorrent plugin, see the instructions [here](https://github.com/autodl-community/autodl-rutorrent/wiki).
