# erase-install

by Graham Pugh

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` is a script to reinstall macOS directly from the system volume using `startosinstall`, which is built into macOS installer applications since version 10.12.4. The `eraseinstall` option was added with macOS 10.13.4.

**It can be used to reinstall, upgrade or erase macOS.**

The script is designed to interact with [mist-cli](https://github.com/ninxsoft/mist-cli), a script developed by Nindi Gill, in order to download a macOS Installer application directly from Apple to the client. The minimum required version is macOS is 10.15.

It is alternatively possible to use the `softwareupdate --fetch-full-installer` command on Mac computers running macOS 11 or greater.

The script has many options to suit a large variety of workflows, management tools and user experiences. Originally designed to work with Macs that are enrolled into Jamf Pro, it now has additional options for use with other management systems or no management systems at all.

## [Please refer to the Wiki for detailed documentation](https://github.com/grahampugh/erase-install/wiki)
