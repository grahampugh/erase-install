erase-install
=============
by Graham Pugh

**WARNING. This is a self-destruct script. Do not try it out on your own device!**

`erase-install.sh` downloads and runs `installinstallmacos.py` from Greg Neagle. `installinstallmacos.py` expects you to choose a value corresponding to the version of macOS you wish to download, so `erase-install.sh` automatically chooses the correct value so that it can be run remotely.

Specifically, this script does the following:

1. Checks whether this script has already been run with the `cache` argument and downloaded an installer dmg to the working directory, and mounts it if so.
2. If not, checks whether a valid existing macOS installer (>= 10.13.4) is already present in the `/Applications` folder
3. If no installer is present, downloads `installinstallmacos.py` and runs it in order to download a valid installer, which is saved to a dmg in the working directory.
5. If run without an argument, runs `startosinstall --eraseinstall` with the relevant options in order to wipe the drive and reinstall macOS.

**NOTE: at present this script uses a forked version of Greg's script so that it can properly automate the download process**

## Options:

* Run the script with the `cache` argument to check and download the installer as required, and copy it to `/Applications`, e.g.

    ```
    sudo bash erase-install.sh cache
    ```

* Run without an argument to check and download the installer as required and then run it to wipe the drive

    ```
    sudo bash erase-install.sh
    ```

## Requirements:

* macOS 10.13.4+ is already installed on the device
* Device file system is APFS
