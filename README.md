# erase-install

by Graham Pugh

![](https://img.shields.io/github/v/release/grahampugh/erase-install)&nbsp;![](https://img.shields.io/github/downloads/grahampugh/erase-install/v27.3/total)&nbsp;![](https://img.shields.io/badge/macOS-10.12.4%2B-success)&nbsp;![](https://img.shields.io/github/license/grahampugh/erase-install)

**Note:** 
The default (`main`) branch is the latest code commit of the production track, which represents versions 28.0 and newer. Any Pull Requests should be made to the `main` branch.

The `release` branch should correspond to the current latest release.

The `legacy` branch is the latest code commit of the legacy track, which represents versions up to 27.x. The legacy track is for those who need to use this script on macOS 10.15 or older.

---

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` is a script to reinstall macOS directly from the system volume using `startosinstall`, which is built into macOS installer applications since version 10.12.4. The eraseinstall option was added with macOS 10.13.4.

**It can be used to reinstall, upgrade or erase macOS.**

The script is designed to interact with `installinstallmacos.py`, a script developed by Greg Neagle, in order to download a macOS Installer application directly from Apple to the client. However, to allow the two scripts to operate better together, a forked version of installinstallmacos.py is used (see [grahampugh/macadmin-scripts](https://github.com/grahampugh/macadmin-scripts)). 

It is alternatively possible to use the `softwareupdate --fetch-full-installer` command that is built in to macOS since 10.15, though the default method is to date more reliable and more flexible.

The script has many options to suit a large variety of workflows, management tools and user experiences. Originally designed to work with Macs that are enrolled into Jamf Pro, it now has additional options for use with other management systems or no management systems at all.

## [Please refer to the Wiki for detailed documentation](https://github.com/grahampugh/erase-install/wiki)
