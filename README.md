erase-install
=============
by Graham Pugh

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` downloads and runs `installinstallmacos.py` from Greg Neagle. `installinstallmacos.py` expects you to choose a value corresponding to the version of macOS you wish to download, so `erase-install.sh` automatically chooses the correct value so that it can be run remotely.

Specifically, this script does the following:

1. Checks whether this script has already been run to download an installer DMG to the working directory, and mounts it if so.
2. If not, checks whether a valid existing macOS installer (>= 10.13.4) is already present in the `/Applications` folder.
3. If no installer is present, downloads `installinstallmacos.py` and runs it in order to download a valid installer, which is saved to a DMG in the working directory.
4. If run with the `--erase` argument, runs `startosinstall --eraseinstall` with the relevant options in order to wipe the drive and reinstall macOS.

**NOTE: at present this script uses a forked version of Greg's script so that it can properly automate the download process**

## Options:

* Run the script with no arguments to download the latest production installer. By default, this is stored in a DMG in the working directory of the `installinstallmacos.py` script.  If an existing installer is found locally on the disk (either in the default location or in `/Applications`), and it is a valid installer (>10.13.4), it will not download it again.

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

* Run the script with argument `--version=10.14` to check for the installer which matches the specified macOS version. This basically filters by version, and looks for the lowest build matching the version. Useful during Golden Master periods.

    ```
    sudo bash erase-install.sh --version=10.14
    ```

* Run the script with argument `--build=XYZ123` to check for the installer which matches the specified build ID, rather than the latest production installer. This allows the reinstallation of a forked or beta version. Note that it will only work if the build is compatible with the device on which you are running the script.

    ```
    sudo bash erase-install.sh --build=XYZ123
    ```

* Run the script with argument `--move` move the downloaded installer to the `/Applications` folder. Note that this argument does not apply in conjunction with the `--erase` flag.

    ```
    sudo bash erase-install.sh --move
    ```

* Run with `--erase` argument to check and download the installer as required and then run it to wipe the drive

    ```
    sudo bash erase-install.sh --erase
    ```

All possible combinations:

    sudo bash erase-install.sh
    sudo bash erase-install.sh --erase
    sudo bash erase-install.sh --move
    sudo bash erase-install.sh --version=10.14
    sudo bash erase-install.sh --version=10.14 --move
    sudo bash erase-install.sh --version=10.14 --erase
    sudo bash erase-install.sh --build=XYZ123
    sudo bash erase-install.sh --build=XYZ123 --move
    sudo bash erase-install.sh --build=XYZ123 --erase
    sudo bash erase-install.sh --samebuild
    sudo bash erase-install.sh --samebuild --move
    sudo bash erase-install.sh --samebuild --erase
    sudo bash erase-install.sh --overwrite
    sudo bash erase-install.sh --overwrite --move
    sudo bash erase-install.sh --overwrite --version=10.14 --move
    sudo bash erase-install.sh --overwrite --build=XYZABC --move
    sudo bash erase-install.sh --overwrite --samebuild --move
    sudo bash erase-install.sh --overwrite --erase
    sudo bash erase-install.sh --overwrite --version=10.14 --erase
    sudo bash erase-install.sh --overwrite --build=XYZABC --erase
    sudo bash erase-install.sh --overwrite --samebuild --erase
    sudo bash erase-install.sh --help

## Requirements:

* macOS 10.13.4+ is already installed on the device
* Device file system is APFS

## Setting up in Jamf Pro

To run this script in Jamf Pro, upload the script, and then create a policy to run it. In the script parameters of the Policy, add the desired options, including the `--`.

For example, to create a policy named `Erase and Reinstall macOS` which is scoped models of Mac that can run the latest standard build, set parameters as follows:

* Parameter 4: `--erase`

If you need a particular fork, create a policy scoped to the devices that require the forked build, and set parameters as follows:

* Parameter 4: `--erase`
* Parameter 5: `--build=18A389`

If you want to precache the installer in /Applications, make a policy named `Download macOS Installer` and set parameters as follows:

* Parameter 4: `--move`
* Parameter 5: `--overwrite`

If you want to precache a particular version, e.g. for upgrading when an older version is still in the software catalog, add Parameter 6:

* Parameter 6: `--version=10.14`
