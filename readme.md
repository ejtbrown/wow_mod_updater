# wow_mod_updater
### Overview
wow_mod_updater is an automatic updater for World of Warcraft AddOns. It was
designed to be used on Linux systems running WoW (presumably in Wine),
although with minimal effort it could be made to work on MacOS systems. It
could probably also work on Windows systems, using Cygwin.

### Prerequisites
This script for the most part uses commands which can be reasonably expected to
be on every Linux / MacOS / Cygwin installation, with the following exceptions:
- python3
- selenium python module
- chromium browser

On Ubuntu, these can be installed with the following:
```
sudo apt install python3 python3-selenium
```

The wow_mod_updater uses Selenium + Chromium instead of command-line options
such as `curl` because CloudFlare firewall restrictions on Curse Forge and
Wow Ace necessitate a full-fledged browser.

### Configuration
The configuration variables are in `wow_mod_updater.rc`. The defaults
(as provided in the repo) are suitable for Ubuntu + Lutris + Wine + WoW,
although they will likely work for _any_ Linux distro + Lutris + Wine + WoW.
The only exception to this statement is the `CHROMIUM_EXECUTABLE` variable,
which may vary significantly for other distributions.

### Getting Started
First, clone the repo!
`git clone https://github.com/ejtbrown/wow_mod_updater.git`

Next, build your list of mods. A sample file is provided (wow_mods.sample).
We'll use it as a starting point:
`cd wow_mod_updater ; cp wow_mods.sample wow_mods`.

Each line in the `wow_mods` file represents an AddOn. The line has two parts,
separated by a space. The first part is the name of the source of the AddOn.
There are presently two valid values: `curse_forge` (for AddOns from Curse) and
`wow_ace` (for AddOns from wowace.com). The second part (after the space) is
the name of the AddOn. In most cases, the name will simply be the
human-readable name with dashes in the place of spaces. But if there is anything
question, just check the URL on the website (Curse or Wow Ace). The name will
be encoded into it. For example, we can browse to Deadly Boss Mods on Curse,
and end up with a URL of:
https://www.curseforge.com/wow/addons/deadly-boss-mods. Looking at the end of
the URL, we can see that the proper name is `deadly-boss-mods`.

Once all of the desired AddOns are in the `wow_mods` file, we can move on to
configuring the script. The defaults that are baked into the `wow_mod_update.rc`
suitable for most Ubuntu + Lutris + Wine configurations. The following configs
are the ones most likely to require attention:

###### MOD_DIR
This value is the path where the actual AddOns are located (i.e. where the WoW
game client will load them from). The default is suitable for Linux + Lutris +
Wine configurations, but can be adjusted to suit. For MacOS and Cygwin users,
this will be the main setting that will need to be set.

###### CHROMIUM_EXECUTABLE
This is the executable path and file name of the Chromium browser.

###### NOTIFY_SEND_LEVEL
This can be set to 0 (disabled), 1 (errors), or 2 (summary). If enabled, the
script will send a desktop notification using `notify-send`, apprising the user
of the outcome of the run. For MacOS and Cygwin users, this should be set to 0.

###### NOTIFY_SEND_PROC
This is the name of the process from which to pull the DBUS session information.
The default (gnome-session) is suitable for X-Windows setups running Gnome.
This value is only used if NOTIFY_SEND_LEVEL is enabled

Once these configuration values have been set, the updater can be run. It can
invoked manually from the command line, or via timed automation such as cron.
The following is a sample cron file (`/etc/cron.d/wow_mod_updater`):

```
# World of Warcraft Mod Updater
0 5 * * * someone sleep $(($RANDOM%3600)) ; /home/someone/wow_mod_updater/wow_mod_updater.sh
```

This crontab will run the updater every morning between 5:00 AM and 6:00 AM.
Adjust as is appropriate.

### Troubleshooting
If something goes wrong, the console output (as the script is running) will
provide some insight. More detailed information can be found in the log file,
`wow_mod_updater.log`.

### Advanced configuration
There are additional configuration options available for the script. They are
documented in the `wow_mod_updater.rc` file itself; each config has a block of
comments above it explaining in gruesome detail how it's used. For most users,
these will not be necessary.
