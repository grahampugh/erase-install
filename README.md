# erase-install

by Graham Pugh

![](https://img.shields.io/github/v/release/grahampugh/erase-install)&nbsp;![](https://img.shields.io/github/downloads/grahampugh/erase-install/latest/total)&nbsp;![](https://img.shields.io/badge/macOS-10.12.4%2B-success)&nbsp;![](https://img.shields.io/github/license/grahampugh/erase-install)

**Note:** The default (`main`) branch repo is the current latest release. There is often a beta version in development. Check the branches for the next release candidate, which will be labelled with the `-rc` suffix. For example, When version 27.2 was the current version, the branch `v28.0-rc` was the next version. **Pull requests will only be accepted on the current beta version.**

---

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` is a script to reinstall macOS directly from the system volume using `startosinstall`, which is built into macOS installer applications since version 10.12.4. The eraseinstall option was added with macOS 10.13.4.

**It can be used to reinstall, upgrade or erase macOS.**

The script is designed to interact with `installinstallmacos.py`, a script developed by Greg Neagle, in order to download a macOS Installer application directly from Apple to the client. However, to allow the two scripts to operate better together, a forked version of installinstallmacos.py is used (see [grahampugh/macadmin-scripts](https://github.com/grahampugh/macadmin-scripts)). 

It is alternatively possible to use the `softwareupdate --fetch-full-installer` command that is built in to macOS since 10.15, though the default method is to date more reliable and more flexible.

The script has many options to suit a large variety of workflows, management tools and user experiences. Originally designed to work with Macs that are enrolled into Jamf Pro, it now has additional options for use with other management systems or no management systems at all.

## [Please refer to the Wiki for detailed documentation](https://github.com/grahampugh/erase-install/wiki)
