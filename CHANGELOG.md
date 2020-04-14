CHANGELOG
=========

# Version History

## 0.12.1
14.04.2020
* Use `--forcequitapps` when *using* the macOS Catalina installer, rather than just when *running* on a macOS Catalina client (issue #25).

## 0.12.0
13.02.2020
* Removed downloaded OS validity check for modes where the installer is not required for reinstall or eraseinstall, to prevent unnecessary exit failures.
* Fixed a problem preveting `--move` from working when overwriting a valid installer.
* Other small bugfixes.

## 0.11.1
03.02.2020
* Restricted the add forcequitapps install_args option to macOS 10.15 or greater, as this is not functional with older versions (#35). Thanks to '@ahousseini' for the contribution.

## 0.11.0
22.01.2020
* Added the `--sameos` option, so you can have a single command which will always try to reinstall whatever macOS (major) version is currently installed on the host.

## 0.10.1
11.12.2019
* Removed check that a user is logged in before proceeding with startosinstall - apparently not necessary after all, and caused at least one user's workflow to break (#33).

## 0.10.0
27.11.2019
* Add a check that there is enough disk space before proceeding  
* Added --forcequitapps argument for 10.15 and above
* Check that a user is logged in before proceeding with startosinstall
* Improved find commands when checking that there is a mounted installer
* Improved German descriptions for reinstallation
* Improved checks for successful downloads from the --fetch_full_installer option

Thanks to '@ahousseini' for various contributions to this release

## 0.9.1
15.11.2019
* Move a comment that states that --fetch-full-installer is available to the correct place (#31)

## 0.9.0
07.10.2019
* Added support for `softwareupdate --fetch-full-installer` and `seedutil` for clients running macOS 10.15 or greater.

## 0.8.0
27.09.2019
* Fixed caffeinate (forgot to make it a background process)
* Added 'Confirm' option for erasing. Thanks to '@ryan-alectrona' for the contribution.

## 0.7.1
26.09.2019
* Added caffeinate to the script to prevent the computer going to sleep during long download phases etc.

## 0.7.0
12.07.2019
* Added `--beta` option.
* Changed behaviour of `--os`, `--version` and auto (i.e. no flag) options to get the latest rather than earliest valid build.
* Removed `install-macos.sh` script. Use `erase-install.sh` with `--reinstall` option instead.

## 0.6.0
19.06.2019
* Added `--reinstall` option, which obsoletes the `install-macos.sh` script.

## 0.5.0
16.04.2019
* Bug fix for empty extra packages folder.  
Thanks to '@Avartharian' for contributions
* Added `--catalogurl` and `--seedprogram` options

## 0.4.0
02.04.2019  
* Added localisation of Jamf Helper messages.  
Thanks to '@ahousseini' for contributions
* Added `--os`, `--path`, `--extras`, `--list` options.  
Thanks to '@mark lamont' for contributions

## 0.3.2
13.12.2018  
* Bug fix for `--build` option, and for exiting gracefully when nothing is downloaded.

## 0.3.1
21.09.2018  
* Added ability to specify a macOS version.  
* Fixed the `--overwrite` flag.  
* Added ability to specify a build in the parameters, and we now clear out the cached content.

## 0.3.0
03.09.2018  
* Additional and amended options for selecting non-standard builds.

## 0.2.0
09.07.2018  
* Automatically selects a non-beta installer.

## 0.1.0
29.03.2018  
* Initial version. Expects a manual choice of installer from `installinstallmacos.py`.
