# erase-install

by Graham Pugh

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` is a script to erase a Mac directly from the system volume, utilising the `eraseinstall` option of `startosinstall`, which is built into macOS installer applications since version 10.13.4.

## Installation

The `erase-install.sh` script can be downloaded directly from GitHub. If run as a standalone script, it will download `installinstallmacos.py` if required for the workflow.

You can also run the script directly from GitHub using the following command from Terminal or with a remote management tool that allows script execution. The `sudo` command can be left off if executing from root prompt or through remote management tool that executes commands with root privilage.

```bash
curl -s https://raw.githubusercontent.com/grahampugh/erase-install/master/erase-install.sh | sudo bash /dev/stdin <arguments>
```

Alternatively, a (signed) package is available which already contains `installinstallmacos.py`, avoiding the need to download it during script operation. See [Releases](https://github.com/grahampugh/erase-install/releases).

You can make your own version of this package by cloning this repo, plus the [grahampugh/macadmins-scripts](https://github.com/grahampugh/macadmin-scripts) and [MunkiPkg](https://www.munki.org/munki-pkg/) and running the `make` command.

## Usage

If run without any options, the script will **not perform the erase**. This means that the script can also be used to pre-cache the installer, or simply to make it available for the user.

So, if run without any options, the script will do the following:

1. Check if an installer is already present in the working directory of this script from a previous run.
2. If not, check if an existing macOS installer is present in the `/Applications` folder. If present, checks that it isn't older than the current installed version.
3. If no valid installer is found, a forked version of `installinstallmacos.py` is downloaded (if not previously downloaded or installed in the working directory). This is used to download the current macOS installer that is valid for this device (determined by Board ID and Model Identifier). The installer is compressed and placed in a `.dmg` in the working directory.

For more information on the forked version of `installinstallmacos.py`, see [grahampugh/macadmin-scripts](https://github.com/grahampugh/macadmin-scripts)

There are a number of options that can be specified to automate this script further:

1. `--erase` runs the `startosinstall` command with the `--eraseinstall` option to wipe the device. The parameter `--confirm` can be added to present the user with a confirmation dialog which must be accepted to perform the erase process.
2. `--reinstall` runs the `startosinstall` command to reinstall the system OS on the device (without erasing the drive). Use this for upgrade/reinstall without losing data.
3. `--move` moved the macOS installer to `/Applications` or to a specified path if it isn't already there.
4. `--overwrite` deletes any existing downloaded installer and re-downloads it.
5. `--update` downloads an installer only if it is newer than the cached one.
6. `--replace_invalid` downloads an installer only if the cached one is invalid for use on this system (usually because the version of the cached installer is older than the current system)

If the `--erase` or `--reinstall` options are used, and additional packages are placed in the folder specified by the variable `extra_installs`, which can be overridden with the `--extras` argument, these packages will be installed as part of the erase-/re-install process. These packages must be signed.

For macOS 10.15 Catalina or greater, experimental support is added for `softwareupdate --fetch-full-installer`. This new functionality can be used to replace the use of `installinstallmacos.py` using the `--fetch-full-installer` option. It will set the seed catalog supplied with the `--seedprogram` argument, using macOS's built in `seedutil` command. The `--fetch-full-installer` option can be used in conjunction with the `--overwrite`, `--reinstall`, and `--erase` options.

For macOS 11 Big Sur or greater, experimental support is added for downloading a macOS Installer pkg. This is taken from Armin Briegel's adaptation of `installinstallmacos.py` at [scriptingosx/fetch-installer-pkg](https://github.com/scriptingosx/fetch-installer-pkg). Use the `--pkg` option to download a package. This can be used in conjunction with `--move` (will extract the package so that you end up with an Installer application in `/Applications`), `--erase` and `reinstall`.

In the event that the `installinstallmacos.py` script that's downloaded via this script isn't working or is out of date, using the option `--force-curl` will force a redownload when `erase-install` runs.

## Full list of Options

- Run the script with argument `--help` to show the available options, then stop.

  ```bash
  sudo bash erase-install.sh --help
  ```

- Run the script with argument `--list` to check the available installers. This will download `installinstallmacos.py` and list the available updates, then stop.

  ```bash
  sudo bash erase-install.sh --list
  ```

- Run the script with no arguments to download the latest production installer. By default, this is stored in a DMG in the working directory of the `installinstallmacos.py` script. If an existing installer is found locally on the disk (either in the default location, or in `/Applications`), and it is a valid installer (>10.13.4), it will not download it again.

  ```bash
  sudo bash erase-install.sh
  ```

- Run the script with argument `--overwrite` to remove any existing macOS installer found in `/Applications` or the working directory, and download the latest production installer. By default, this is stored in a DMG in the working directory of the `installinstallmacos.py` script.

  ```bash
  sudo bash erase-install.sh --overwrite
  ```

- Run the script with argument `--replace_invalid` to remove any existing macOS installer found in `/Applications` or the working directory that is older than the current system, and download the latest production installer. By default, this is stored in a DMG in the working directory of the `installinstallmacos.py` script.

  ```bash
  sudo bash erase-install.sh --replace_invalid
  ```

- Run the script with argument `--update` to remove any existing macOS installer found in `/Applications` and download the latest production installer, but only if the latest poduction installer is newer than the cached one. By default, this is stored in a DMG in the working directory of the `installinstallmacos.py` script.

  ```bash
  sudo bash erase-install.sh --update
  ```

- Run the script with argument `--samebuild` to check for the installer which matches the current system macOS build (using `sw_vers`), rather than the latest production installer. This allows the reinstallation of a forked or beta version that is already installed on the system volume.

  ```bash
  sudo bash erase-install.sh --samebuild
  ```

- Run the script with argument `--sameos` to check for the installer which matches the currently installed macOS major version. This basically filters by version, and looks for the latest build matching the version. Useful if you want to avoid upgrading during erase-install, but don't want to have to specify a particular OS.

  ```bash
  sudo bash erase-install.sh --sameos
  ```

- Run the script with argument `--os=10.14` to check for the installer which matches the specified macOS major version. This basically filters by version, and looks for the latest build matching the version. Useful during Golden Master periods. Note that for macOS 11+, `--os=11` is treated as the major version rather than `10.x`.

  ```bash
  sudo bash erase-install.sh --os=10.14
  ```

- Run the script with argument `--version=10.14.3` to check for the installer which matches the specified macOS point version. This basically filters by version, and looks for the lowest build matching the version.

  ```bash
  sudo bash erase-install.sh --version=10.14.3
  ```

- Run the script with argument `--build=XYZ123` to check for the installer which matches the specified build ID, rather than the latest production installer or the same build. Note that it will only work if the build is compatible with the device on which you are running the script.

  ```bash
  sudo bash erase-install.sh --build=XYZ123
  ```

- Run the script with argument `--move` to move the downloaded installer to the `/Applications` folder. Note that this argument does not apply in conjunction with the `--erase` or `f` flags.

  ```bash
  sudo bash erase-install.sh --move
  ```

- Run the script with arguments `--move` and `--path=/some/path` to move the downloaded installer to the specified folder. Note that this argument does not apply in conjunction with the `--erase` flag.

  ```bash
  sudo bash erase-install.sh --move --path=/path/to/move/to
  ```

- Run with `--erase` argument to check and download the installer as required and then run it to wipe the drive. Can be used in conjunction with the `--os`, `--version`, `--build`, `--sameos`, `--samebuild`, `--overwrite`, `--replace_invalid` and `--update` flags.

  ```bash
  sudo bash erase-install.sh --erase
  ```

- If the `--erase` option is used, and additional packages are placed in the folder specified by the variable `extra_installs`, these packages will be as part of the erase-install process. These packages must be signed. The path to these packages can be overridden with the `--extras` argument.

  ```bash
  sudo bash erase-install.sh --erase --extras=/path/containing/extra/packages
  ```

- If both the `--erase` and `--confirm` options are used, a Jamf Helper window is displayed and the user is prompted to confirm erasure prior to taking any action. If the user chooses to cancel, the script will exit.

  ```bash
  sudo bash erase-install.sh --erase --confirm
  ```

- Run with `--reinstall` argument to check and download the installer as required and then run it to reinstall macOS on the system volume. Can be used in conjunction with the `--os`, `--version`, `--build`, `--sameos`, `--samebuild`, `--overwrite`, `--replace_invalid` and `--update` flags.

  ```bash
  sudo bash erase-install.sh --reinstall
  ```

- If the `--reinstall` option is used, and additional packages are placed in the folder specified by the variable `extra_installs`, these packages will be as part of the reinstall process. These packages must be signed. The path to these packages can be overridden with the `--extras` argument.

  ```bash
  sudo bash erase-install.sh --reinstall --extras=/path/containing/extra/packages
  ```

-- If the `--check-power` option is used, the script will check if the computer is connected to AC power. If it isn't, it will wait for a default of 60 seconds for power to be added, and otherwise fail. The default time to wait can be altered by setting the `--power-wait-limit` option, e.g. `--power-wait-limit 180` for 3 minutes.

### Option in Catalina or greater only

- Run the script with the `--fetch-full-installer` argument to download the latest production installer using `softwareupdate --fetch-full-installer`. This downloads the current latest installer to `/Applications` (the `--move` option does not function here). If an existing installer is found locally on the disk (either in the default location, or in `/Applications`), and it is a valid installer (>10.13.4), it will not download it again. Can be used in conjunction with the `--version=10.X.Y`, `--reinstall` and `--erase` arguments.

  ```bash
  sudo bash erase-install.sh --fetch-full-installer
  ```

### Option for obtaining Big Sur or greater only

- Run the script with the `--pkg` argument to download the latest production installer as a package. This downloads the current latest installer as a package in the working directory. If an existing installer or package is found locally on the disk (either in the default location, or in `/Applications`), and it is a valid installer (>10.13.4), it will not download it again. Can be used in conjunction with the `--version=11.X.Y`, `--reinstall` and `--erase` arguments.

  ```bash
  sudo bash erase-install.sh --pkg
  ```

## Requirements for performing the erase-install

- macOS 10.13.4+ is already installed on the device
- Device file system is APFS

Note that downloading the installer does not require 10.13.4 or APFS, it is just the `startosinstall --eraseinstall` command that requires it.

## Dialog options

If the computer on which the script is running is enrolled to Jamf Pro, dialogs will be shown using the `jamfHelper` tool. Otherwise `osascript` dialogs are used.

The `--no-jamfhelper` option causes `jamfHelper` to be ignored.

The `--depnotify` option uses DEPNotify for dialogs.

## Setting up in Jamf Pro

To run this script in Jamf Pro, upload the script, and then create a policy to run it. In the script parameters of the Policy, add the desired options, including the `--`.

For example, to create a policy named `Erase and Reinstall macOS` which is scoped models of Mac that can run the latest standard build, set parameters as follows:

- Parameter 4: `--erase`

If you need a particular fork, create a policy scoped to the devices that require the forked build, and set parameters as follows:

- Parameter 4: `--erase`
- Parameter 5: `--build=18A389`

## Using the `erase-install.sh` script to cache the installer

If you want to pre-cache the installer in `/Applications` for use by another policy, make a policy named `Download macOS Installer` and set parameters as follows:

- Parameter 4: `--move`
- Parameter 5: `--overwrite` to replace any cached installer, or `--update` to only replace any cached installer if a newer one is available, or `--replace_invalid` to only update a cached installer if it is no longer valid on this system.

If you want to upgrade to macOS 10.14 while 10.13 installers are still available in the catalog, add this additional flag:

- Parameter 6: `--os=10.14`

Or if you need to specify a particular point release version (say if more than one is available in the catalogue), add this additional flag:

- Parameter 6: `--version=10.14.3`

Once the installer is in place in `/Applications` folder, you can create another policy using the same script to perform an in-place upgrade using the `--reinstall` option, without erasing the system.

## Note about supplying values to parameters/options

`erase-install.sh` allows you to specify values to command line options in two ways, either with a space or with an equals sign, e.g. `--version 10.14.3` or `--version=10.14.3`. If using Script Parameters in Jamf Pro, please ensure you use the equals sign, e.g. `--version=10.14.3`.
