# wow_mod_updater
### Overview
wow_mod_updater is an automatic updater for World of Warcraft AddOns. It was
designed to be used on Linux systems running WoW (presumably in Wine),
although with minimal effort it could be made to work on MacOS systems. It
could probably also work on Windows systems, using Cygwin.

### Configuration
The configuration variables are located at the top of the script. The defaults
(as provided in the repo) are suitable for Ubuntu + Lutris + Wine + WoW,
although they will likely work for _any_ Linux distro + Lutris + Wine + WoW.

### Getting Started
First, clone the repo!
`git clone https://github.com/ejtbrown/wow_mod_updater.git`

Next, build your list of mods. A sample file is provided (wow_mods.sample).
We'll use it as a starting point:
`cd wow_mod_updater ; cp wow_mods.sample wow_mods`.

Once all of the desired AddOns are in the `wow_mods` file, we can move on to
configuring the script. The defaults that are baked into the script are suitable
for most Ubuntu + Lutris + Wine configurations. The following configs (all of
which are toward the top of the script itself) are the ones most likely to
require attention:

###### MOD_DIR
This value is the path where the actual AddOns are located (i.e. where the WoW
game client will load them from). The default is suitable for Linux + Lutris +
Wine configurations, but can be adjusted to suit. For MacOS and Cygwin users,
this will be the main setting that will need to be set.

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
0 5 * * * someone /home/someone/wow_mod_updater/wow_mod_updater.sh
```

This crontab will run the updater every morning at 5:00 AM. Adjust as is
appropriate.

### Advanced configuration
There are additional configuration options available in the script. They already
documented in the script itself; each config has a block of comments above it
explaining in gruesome detail how it's used. For most users, these will not be
necessary.
