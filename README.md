erase-install
=============
by Graham Pugh

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` is a script to erase a Mac directly from the system volume, utilising the `eraseinstall` option of `startosinstall`, which is built into macOS installer applications since version 10.13.4.

If run without any options, the script will **not perform the erase**. This means that the script can also be used to pre-cache the installer, or simply to make it available for the user.

So, if run without any options, the script will do the following:

1. Check if an installer is already present in the working directory of this script from a previous run.
2. If not, check if an existing macOS installer is present in the `/Applications` folder. If present, checks that it isn't older than the current installed version.
3. If no valid installer is found, a forked version of `installinstallmacos.py` is downloaded. This is used to download the current macOS installer that is valid for this device (determined by Board ID and Model Identifier). The installer is compressed and placed in a `.dmg` in the working directory.

For more information on the forked version of `installinstallmacos.py`, see [grahampugh/macadmin-scripts](https://github.com/grahampugh/macadmin-scripts)

There are a number of options that can be specified to automate this script further:

1. `--erase` runs the `startosinstall` command with the `--eraseinstall` option to wipe the device.
2. `--move` moved the macOS installer to `/Applications` or to a specified path if it isn't already there.
3. `--overwrite` deletes any existing downloaded installer and re-downloads it.

## Full list of Options:

* Run the script with argument to check the available installers. This will download `installinstallmacos.py` and list the available updates, then stop.

    ```
    sudo bash erase-install.sh --list
    ```

* Run the script with no arguments to download the latest production installer. By default, this is stored in a DMG in the working directory of the `installinstallmacos.py` script.  If an existing installer is found locally on the disk (either in the default location, or in `/Applications`), and it is a valid installer (>10.13.4), it will not download it again.

    ```
    sudo bash erase-install.sh
    ```

* Run the script with argument `--overwrite` to remove any existing macOS installer found in `/Applications` and download the latest production installer. By default, this is stored in a DMG in the working directory of the `installinstallmacos.py` script.

    ```
    sudo bash erase-install.sh --overwrite
    ```

* Run the script with argument `--samebuild` to check for the installer which matches the current system macOS build (using `sw_vers`), rather than the latest production installer. This allows the reinstallation of a forked or beta version that is already installed on the system volume.

    ```
    sudo bash erase-install.sh --samebuild
    ```

* Run the script with argument `--os=10.14` to check for the installer which matches the specified macOS major version. This basically filters by version, and looks for the lowest build matching the version. Useful during Golden Master periods.

    ```
    sudo bash erase-install.sh --os=10.14
    ```

* Run the script with argument `--version=10.14.3` to check for the installer which matches the specified macOS point version. This basically filters by version, and looks for the lowest build matching the version. Useful during Golden Master periods.

    ```
    sudo bash erase-install.sh --version=10.14.3
    ```

* Run the script with argument `--build=XYZ123` to check for the installer which matches the specified build ID, rather than the latest production installer or the same build. Note that it will only work if the build is compatible with the device on which you are running the script.

    ```
    sudo bash erase-install.sh --build=XYZ123
    ```

* Run the script with argument `--move` to move the downloaded installer to the `/Applications` folder. Note that this argument does not apply in conjunction with the `--erase` flag.

    ```
    sudo bash erase-install.sh --move
    ```

* Run the script with arguments `--move` and `--path=/some/path` to move the downloaded installer to the specified folder. Note that this argument does not apply in conjunction with the `--erase` flag.

    ```
    sudo bash erase-install.sh --move --path=/path/to/move/to
    ```

* Run with `--erase` argument to check and download the installer as required and then run it to wipe the drive

    ```
    sudo bash erase-install.sh --erase
    ```

All possible combinations:

    sudo bash erase-install.sh
    sudo bash erase-install.sh --erase
    sudo bash erase-install.sh --move
    sudo bash erase-install.sh --os=10.14
    sudo bash erase-install.sh --os=10.14 --move
    sudo bash erase-install.sh --os=10.14 --erase
    sudo bash erase-install.sh --version=10.14.3
    sudo bash erase-install.sh --version=10.14.3 --move
    sudo bash erase-install.sh --version=10.14.3 --erase
    sudo bash erase-install.sh --build=XYZ123
    sudo bash erase-install.sh --build=XYZ123 --move
    sudo bash erase-install.sh --build=XYZ123 --erase
    sudo bash erase-install.sh --samebuild
    sudo bash erase-install.sh --samebuild --move
    sudo bash erase-install.sh --samebuild --erase
    sudo bash erase-install.sh --overwrite
    sudo bash erase-install.sh --overwrite --move
    sudo bash erase-install.sh --overwrite --os=10.14 --move
    sudo bash erase-install.sh --overwrite --version=10.14.3 --move
    sudo bash erase-install.sh --overwrite --build=XYZABC --move
    sudo bash erase-install.sh --overwrite --samebuild --move
    sudo bash erase-install.sh --overwrite --erase
    sudo bash erase-install.sh --overwrite --os=10.14 --erase
    sudo bash erase-install.sh --overwrite --version=10.14.3 --erase
    sudo bash erase-install.sh --overwrite --build=XYZABC --erase
    sudo bash erase-install.sh --overwrite --samebuild --erase
    sudo bash erase-install.sh --list
    sudo bash erase-install.sh --help

## Requirements for performing the eraseinstall:

* macOS 10.13.4+ is already installed on the device
* Device file system is APFS

Note that downloading the installer does not require 10.13.4 or APFS, it is just the `starts install --eraseinstall` command that requires it.

## Setting up in Jamf Pro

To run this script in Jamf Pro, upload the script, and then create a policy to run it. In the script parameters of the Policy, add the desired options, including the `--`.

For example, to create a policy named `Erase and Reinstall macOS` which is scoped models of Mac that can run the latest standard build, set parameters as follows:

* Parameter 4: `--erase`

If you need a particular fork, create a policy scoped to the devices that require the forked build, and set parameters as follows:

* Parameter 4: `--erase`
* Parameter 5: `--build=18A389`

## Using the `erase-install.sh` script to cache the installer for use with the `install-macos.sh` script

If you want to pre-cache the installer in `/Applications` for use by another policy, make a policy named `Download macOS Installer` and set parameters as follows:

* Parameter 4: `--move`
* Parameter 5: `--overwrite`

If you want to upgrade to macOS 10.14 while 10.13 installers are still available in the catalog, add this additional flag:

* Parameter 6: `--os=10.14`

Or if you need to specify a particular point release version (say if more than one is available in the catalogue), add this additional flag:

* Parameter 6: `--os=10.14.3`

Once the installer is in place in `/Applications` folder, you can use the `install-macOS.sh` script included here in a different policy to perform an in-place upgrade, without erasing the system.
