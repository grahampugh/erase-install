# erase-install

by Graham Pugh

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` is a script to reinstall macOS directly from the system volume using `startosinstall`, a resource binary which has been built into macOS installer applications since version 10.12.4. The `--eraseinstall` option was added with macOS 10.13.4 for computers with an APFS system volume.

**It can be used to download, reinstall, upgrade or erase macOS.**

The script is designed to interact with [mist-cli](https://github.com/ninxsoft/mist-cli), a script developed by Nindi Gill, in order to download a macOS Installer application directly from Apple to the client. The minimum required version is macOS 10.15.

It is alternatively possible to use the `softwareupdate --fetch-full-installer` command on Mac computers running **macOS 11 or greater** (macOS 11 is required because the `--list-full-installers` option is used to find valid builds).

The script is also designed to interact with [swiftDialog](https://github.com/bartreardon/swiftDialog) for providing dialogues to users. **The minimum required version for swiftDialog is macOS 11**.

The script has many options to suit a large variety of workflows, management tools and user experiences. Originally designed to work with Macs that are enrolled into Jamf Pro, it now has additional options for use with other management systems or no management systems at all.

## [Please refer to the Wiki for detailed documentation](https://github.com/grahampugh/erase-install/wiki)
