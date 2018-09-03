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

* Run the script with argument `--move` move the downloaded installer to the `/Applications` folder. Note that this argument does not apply in conjunction with the `--erase` flag.

    ```
    sudo bash erase-install.sh --move
    ```

* Run with `--erase` argument to check and download the installer as required and then run it to wipe the drive

    ```
    sudo bash erase-install.sh --erase
    ```

All possible combinations:

    ```
    sudo bash erase-install.sh
    sudo bash erase-install.sh --erase
    sudo bash erase-install.sh --move
    sudo bash erase-install.sh --samebuild
    sudo bash erase-install.sh --samebuild --move
    sudo bash erase-install.sh --samebuild --erase
    sudo bash erase-install.sh --overwrite
    sudo bash erase-install.sh --overwrite --move
    sudo bash erase-install.sh --overwrite --samebuild --move
    sudo bash erase-install.sh --overwrite --erase
    sudo bash erase-install.sh --overwrite --samebuild --erase
    sudo bash erase-install.sh --help
    ```

## Requirements:

* macOS 10.13.4+ is already installed on the device
* Device file system is APFS
