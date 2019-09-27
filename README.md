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

1. `--erase` runs the `startosinstall` command with the `--eraseinstall` option to wipe the device. The parameter `--confirm` can be added to present the user with a confirmation dialog which must be accepted to perform the erase process.
2. `--reinstall` runs the `startosinstall` command to reinstall the system OS on the device (without erasing the drive). Use this for upgrade/reinstall without losing data.
3. `--move` moved the macOS installer to `/Applications` or to a specified path if it isn't already there.
4. `--overwrite` deletes any existing downloaded installer and re-downloads it.

If the `--erase` or `--reinstall` options are used, and additional packages are placed in the folder specified by the variable `extra_installs`, which can be overridden with the `--extras` argument, these packages will be as part of the erase-/re-install process. These packages must be signed.

## Full list of Options:

* Run the script with argument `--help` to show the available options, then stop.

    ```
    sudo bash erase-install.sh --help
    ```

* Run the script with argument `--list` to check the available installers. This will download `installinstallmacos.py` and list the available updates, then stop.

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

* Run with `--erase` argument to check and download the installer as required and then run it to wipe the drive. Can be used in conjunction with the `--os`, `--version`, `--build`, `--samebuild` and `--overwrite` flags.

    ```
    sudo bash erase-install.sh --erase
    ```

* If the `--erase` option is used, and additional packages are placed in the folder specified by the variable `extra_installs`, these packages will be as part of the erase-install process. These packages must be signed. The path to these packages can be overridden with the `--extras` argument.

    ```
    sudo bash erase-install.sh --erase --extras=/path/containing/extra/packages
    ```
* If both the `--erase` and `--confirm` options are used, a Jamf Helper window is displayed and the user is prompted to confirm erasure prior to taking any action. If the user chooses to cancel, the script will exit.

    ```
    sudo bash erase-install.sh --erase --confirm
    ```

* Run with `--reinstall` argument to check and download the installer as required and then run it to reinstall macOS on the system volume. Can be used in conjunction with the `--os`, `--version`, `--build`, `--samebuild` and `--overwrite` flags.

    ```
    sudo bash erase-install.sh --reinstall
    ```

* If the `--reinstall` option is used, and additional packages are placed in the folder specified by the variable `extra_installs`, these packages will be as part of the reinstall process. These packages must be signed. The path to these packages can be overridden with the `--extras` argument.

    ```
    sudo bash erase-install.sh --reinstall --extras=/path/containing/extra/packages
    ```

## Requirements for performing the eraseinstall:

* macOS 10.13.4+ is already installed on the device
* Device file system is APFS

Note that downloading the installer does not require 10.13.4 or APFS, it is just the `startosinstall --eraseinstall` command that requires it.

## Setting up in Jamf Pro

To run this script in Jamf Pro, upload the script, and then create a policy to run it. In the script parameters of the Policy, add the desired options, including the `--`.

For example, to create a policy named `Erase and Reinstall macOS` which is scoped models of Mac that can run the latest standard build, set parameters as follows:

* Parameter 4: `--erase`

If you need a particular fork, create a policy scoped to the devices that require the forked build, and set parameters as follows:

* Parameter 4: `--erase`
* Parameter 5: `--build=18A389`

## Using the `erase-install.sh` script to cache the installer

If you want to pre-cache the installer in `/Applications` for use by another policy, make a policy named `Download macOS Installer` and set parameters as follows:

* Parameter 4: `--move`
* Parameter 5: `--overwrite`

If you want to upgrade to macOS 10.14 while 10.13 installers are still available in the catalog, add this additional flag:

* Parameter 6: `--os=10.14`

Or if you need to specify a particular point release version (say if more than one is available in the catalogue), add this additional flag:

* Parameter 6: `--os=10.14.3`

Once the installer is in place in `/Applications` folder, you can create another policy using the same script to perform an in-place upgrade using the `--reinstall` option, without erasing the system.
