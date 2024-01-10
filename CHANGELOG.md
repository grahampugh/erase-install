# CHANGELOG

## [Untagged]

No date

## [32.0]

10.01.2024

- Include a compatibility check for cached installers, utilising data from the `com_apple_MobileAsset_MacSoftwareUpdate.xml` file within the `Shared Support.dmg`. This should prevent installers that were not obtained using erase-install from running if they are not compatible with the system.
- Add the ability to change the default icon size in dialogs, and to supply an alternative icon for confirmation dialogs (#462, addressed in #463, thanks to @popaprozac).
- Bump swiftDialog version to 2.3.3 except for systems running macOS 11 which still get 2.2.1. Note that the installer package includes version 2.3.3. If running on Big Sur, this will be deleted and an internet connection is required to download version 2.2.1.
- Fix swiftDialog URL, which has moved (#469, thanks to @scottborcherdt).
- Replaced some SF Symbol icons in dialogs for compatibility with macOS 11 (fixes #470, thanks to @BigMacAdmin).

## [31.0]

27.09.2023

- Bump mist-cli version to 2.0.
- Bump swiftDialog version to 2.3.2 except for systems running macOS 11 which still get 2.2.1. Note that the installer package includes version 2.3.2. If running on Big Sur, this will be deleted and an internet connection is required to download version 2.2.1.
- Added localisation for Brazilian Portuguese (#432, thanks to @hooleahn).
- `--os` searches will search for the relevant version name rather than number, to avoid a bug in mist-cli that may result in download an inappropriate installer if the chosen major OS is not available. Note that this bug is fixed in mist-cli 2.0, but I'll leave the workaround in place for the time being.
- Use icons in the GitHub repo instead of using the InstallAssistant icon which occasionally doesn't render.
- Stop trying to use `seedutil` on 13.4 or newer when using the `--ffi` option as it doesn't work any more.
- Moved up the log rotation so that we get all output of the current run, and made it less verbose.
- Add macOS Sonoma catalog.
- Invalid package is removed when using `--replace-invalid` or `--update` regardless of whether the `--pkg` option is selected or not.

## [30.2]

24.08.2023

- Emergency release to fix the listing of 13.6 RC in the regular lists. This is caused due to the mist-cli default catalogs including the seed catalogs. Now the production catalog is specified unless using the `--beta` option.

## [30.1]

28.07.2023

- (Hopefully temporary) fix for a bug in mist-cli where it isn't setting the permissions of the Install application properly.
- Remove ANSI formatting from mist-cli output when listing installers.
- Output stderr from swiftDialog to dev/null to avoid occasional Xfont error warnings in logs
- Minor fixes.

## [30.0]

18.07.2023

- Converted to `zsh` (but the filename remains erase-install.sh).
- Bumped the compatible version of mist-cli to v1.14.
- Bumped the compatible version of swiftDialog to 2.2.1.4591.
- Can now run `erase-install.sh --list` safely as the current user (without sudo); logs and files are written to a temporary location.
- A notification is shown if running an older version of erase-install than the latest available (on macOS 13 or newer).
- Allows `mist` to use a caching server (addresses #406). Add the following option:
  - `--caching-server https://YOUR_URL_HERE`
- It is now possible to supply credentials in base64 format to avoid the prompt for credentials on Apple Silicon computers.
  - **NOTE THIS IS VERY INSECURE! ONLY USE IN A SAFE ENVIRONMENT!!!**
  - Use the supplied script `set-credentials.sh` to generate the base64-encoded credentials.
  - Alternatively use the following shell command: `printf "%s:%s" "<USERNAME>" "<PASSWORD>" | iconv -t ISO-8859-1 | base64 -i -`
  - Add the following option: `--credentials ENCODEDCREDENTIALS`
  - Also add this option: `--very-insecure-mode` (this is required in addition to the `--credentials` option!).
- If running the script on macOS 11, it now checks ot see if the swiftDialog version is too new (addresses #392).
- `--update` no longer ignores `--sameos` (fixes #407).
- `erase-install-launcher.sh` is also converted to zsh.
- `erase-install-launcher.sh` should now respect parameters that have spaces in them, such as commands called by the `--postinstall-command` option.
- Fixed version comparisons where there is a point release (fixes #410).
- Pre- and post-install commands are now run in `--test-run` mode.
- Now exits out when some incompatible arguments are provided at the same time.

## [29.2]

07.06.2023

- Fix downloads from mist only selecting compatible builds.
- Version bump to use mist-cli v1.12, which includes a less verbose output for the download logs (one register per percentage download instead of one register per second).

## [29.1]

27.02.2023

- `--os` can now be used along with `--fetch-full-installer`.
- Remove audible sound when 1 hour timeout is reached.
- Log output from `mist` is now somewhat reduced due to the use of the `no-ansi` mode.
- Add `--quiet` option to prevent output from mist during download. Note that with this mode enabled, there is no download progress bar, since the output is required to read the download progress.
- Log files are now rotated up to 9 times (#369, thanks to @aschwanb).

### Bugfixes

- Do not list deferred updates when using along `--list` with  `--fetch-full-installer` (addresses #347).
- Fix issue with swiftDialog windows not showing up. This was due to a change in behaviour in swiftDialog version 2.1 enforcing running the app as the local user rather than root, which meant that the log file could not be overwritten. The log file is now deleted after use and each run creates a random logfile path (addresses #352, #366 and #368).
- Reintroduce `--skip-validation` functionality.
- Fix issue with using `--version` along with `--fetch-full-installer`.
- Fix a problem where `mist` did not correctly output (addresses #357).

## [29.0]

10.02.2023

- New `--check-fmm` option to prompt the user to disable Find My Mac if it is enabled (in `--erase` mode only). The default wait limit is 5 minutes before failing. This can be altered using a new `--fmm-wait-limit` option.

### Bugfixes

- Fixed Minimum Drive Space dialog not showing (fixes #353).
- Fixed incorrect full screen "reboot delay" screen (fixes #348). If `--fs` mode is used, the fullscreen preparation window now remains until the end of the reboot delay period.
- Fixed some incorrect/inconsistent window and icon sizes.
- Fixed some missing window titles.
- Fixed missing icon on macOS<13.

## [28.1]

28.01.2023

- `--cache-downloads` option. In 28.0, `mist` cached downloads into `/private/tmp/com.ninxsoft.mist`. This is now optional.
- New experimental `--set-securebootlevel` option (in `--erase` mode only) uses the command `bputil -f -u $current_user -p $account_password` to ensure that the OS is reset to a high secure boot level after reinstallation (thanks to @mvught). 
- New experimental `--clear-firmware` option (in `--erase` mode only) uses the command `nvram -c` to ensure that the OS is reset to a high secure boot level after reinstallation (thanks to @mvught).
- `erase-install` now reports a non-zero exit code (143 to be exact) when it is being abnormally terminated (e.g. by pressing CTRL+C or getting terminated by SIGTERM). Previously it would return the exit code of the last command being executed at time of termination, which could be non-zero or zero depending on the specific circumstances, which then could have been reported as successful execution in a Jamf policy. This change will make it easier to discover such errors. The exit code of the last executed command will be logged in addition to returning 143 to facilitate debugging (#318, thanks @cvgs).

### Bugfixes

- `mist` result is now correctly interpreted when checking for a newer version.
- The `--update` option now triggers an invalid installer to be overwritten.
- Progress is now once again shown during the preparation phase, and the progress bar properly shows incremental progress.

## [28.0]

24.01.2023

- Calls to `installinstallmacos.py` have been replaced with calls to `mist`. Minimum OS requirement for this is macOS 10.15.
- Dialogues are now all presented using [swiftDialog](https://github.com/bartreardon/swiftDialog). **Minimum OS requirement for this is macOS 11.**
- The minimum compatible OS for swiftDialog is macOS Big Sur 11. If you need to upgrade a Mac on an older version of macOS, use Version 27.x of erase-install.
- Downloads are now only available as a `pkg` or an `app`. Downlaoding of a `sparseimage` has been discontinued, though the script will continue to search for them to allow for upgrade from earlier versions of erase-install without having to re-download the installer.
- The log has moved to `/Library/Management/erase-install/log/erase-install.log`
- New `--silent` mode. The script can now be run without any dialogues. On Apple Silicon, this requires the use of the keychain method to provide credentials. Minimum OS requirement for this is macOS 10.15.
- Add Spanish dialogs.
- For testing purposes, a username and password may be placed in a custom keychain. Username is optional as the current user can be used. To create the keychain and add the keys, run the following commands:
  - `security create-keychain -P NAME_OF_KEYCHAIN` - this will prompt you to create a password for the keychain. The keychain will be stored in `~/Library/Keychains`. `NAME_OF_KEYCHAIN` must match the value you give to the `--kc` key. The password you create must match the value you give to the `--kc-pass` key.
  - `security add-generic-password -s NAME_OF_SERVICE -a NAME_OF_USER -w PASSWORD NAME_OF_KEYCHAIN` - `NAME_OF_SERVICE` must match the value you provide to the `--kc-service` key. `NAME_OF_USER` and `PASSWORD` must be the valid credentials of an account on the computer with Volume Ownership.
  
### Known issues

- Some processes appear to still run after the script has finished when using `--test-run`. These do not appear to affect future usage, but you may hear a timeout alert after one hour.
- It is not currently possible to download an installer app to a location of your choice, such as the working directory. The app is always downloaded to `/Applications`.

## [27.3]

24.01.2023

- (change to `installinstallmacos.py`): version comparisons are now done with the python module `packaging.version.LegacyVersion`, as `parse_version` proved unreliable.

## [27.2]

14.12.2022

- Better handling of replacing broken sparseimage files. If `--overwrite`, `--update`, or `--replace-invalid` are used and the version cannot be obtained from the sparseimage, the installer should be downloaded again. This also fixes `--overwrite` where an existing sparseimage is present. 
- Add `--no-timeout` option which extends the timeout period to 24h.

## [27.1]

24.10.2022

- Add catalog for macOS Ventura to `installinstallmacos.py`, update checksum in `erase-install.sh`.

## [27.0]

14.10.2022

- Allows for logs to be reported back to Jamf Pro by changing the method `startosinstall` is launched. This requires `rebootdelay` to be set, which allows uploading the script result to Jamf Pro before `startosinstall` force-quits our script and reboots the machine (thanks to @cvgs).
- Adds launcher script `erase-install-launcher.sh` which can be used to start the pkg-delivered version of erase-install from the Scripts section of Jamf Pro (it also supports more than 8 arguments for `erase-install` because you can add multiple arguments in one Jamf Parameter field) (thanks to @cvgs).
- Adds some fallbacks for the `--fetch-full-installer` option.
- If no build ID is found in the existing installer, we set it as invalid instead of exiting the script (addresses #271, thanks to @sphen13).
- Fix the fallback free disk space calculation (`df` was returning disk size in kb and not gb) (#274 - thanks to @sphen13).
- `--update` option now uses new logic in `installinstallmacos.py` to restrict searches to a certain OS or version (addresses #287).
- Improved function descriptions in the script.
- Changed the `Makefile` to download the correct version of `installinstallmacos.py` during the make process.
- Improved checksum checks for `installinstallmacos.py` - if an incorrect checksum is found, the correct version is downloaded rather than the script failing (unless `--no-curl` option has been added).
- Add titles to username and password dialog boxes (#289, thanks to @cvgs)
- Now correctly deletes a sparseimage from the cache when `--move` is used and the sparseimage is downloaded (#297, thanks to @andyincali)
- Now correctly fails if an invalid installer is found and `--replace-invalid`, `--update`, `--overwrite` or `--skip-validation` are not set (addresses #298).

## [26.2]

23.07.2022

- Allows `rebootdelay` for 10.15 (thanks to @cvgs).
- New `--newvolumename` key which will set the volume name after an `eraseinstall` workflow (thanks to @bmacphail).
- Now correctly validates whether a selected build value matches the cached installer.

## [26.1]

27.06.22

- Universal python build packages.
- Use `pkg_resources` instead of `distutils` where available (allows for removal if `distutils` in python 3.12 - addresses [grahampugh/macadmin-scripts/issues/47](https://github.com/grahampugh/macadmin-scripts/issues/47)).
- Improves the `--fetch-full-installer` option by looking for the latest version if not specified, and checking that a pre-chosen version is in the list. `--list` in conjunction with `--ffi` also now uses `--list-full-installers` instead of reverting to `installinstallmacos.py`.
- Allows the usage of spaces in `--workdir` and `--path` (thanks to @cvgs).
- Added `--max-password-attempts=NN` option, which can also be set to `infinite` to prevent canceling the password dialog (addresses #216, thanks to @cvgs).
- Changes dialogs so that the Cancel button is on the left, and default button is on the right (thanks to @cvgs).
- Script now uses `sysctl` to check for Apple Silicon (addresses #225, thanks to @cvgs).
- Some minor changes to the German translation (thanks to @cvgs).
- Adds an additional check for `--min-drive-space` right before start of the installation (should address #242, thanks to @cvgs).
- Adds `-nobrowse` to all instances of `hdiutil` to prevent mounted images appearing on the desktop (thanks to @cvgs).

## [26.0]

No date

- Adds `--catalog` to allow an easier way to select which software update catalog to use, rather than the defaults set in `installinstallmacos.py`. Example: `--catalog 10.15` will use the catalog for Darwin version 19, `--catalog 11` will use Darwin version 20. This is to address omissions in the catalogs for older OSes (somewhat addresses #169, #160).
- Allow for more lenient checks for Volume Ownership against the entered username (#177, thanks to @cvgs)
- Adds `--rebootdelay` option (Big Sur or later) (#193).
- DEPNotify counts down the rebootdelay time.
- Adds `--fs` option which makes all the DEPNotify windows full screen (download, confirm, preparation).
- User can dismiss the DEPNotify download and preparation windows if `--rebootdelay` is set to at least 10 seconds.
- Multiple `--preinstall-command` arguments can now be supplied. These run immediately before `startosinstall` is run.
- Multiple `--postinstall-command` arguments can now be supplied. These run after `startosinstall` has finished.
- Checksums of `installinstallmacos.py` are now pinned to a tag of the `macadmins-scripts` repo so that updates to the script don't break a particular version of `erase-install.sh` from working.
- Add a message about process Terminations, which some people were mistakenly believing to be errors.
- Fixed the actual killing of jamfHelper and caffeinate.
- `osascript` dialog windows now run as the user (addresses #198, thanks to @anewhouse).
- Fixed an issue concerning the catalog for macOS High Sierra 10.13 which has an item without a version string listed, which was causing installinstallmacos.py to error out (addresses #169).

## [25.0]

23.11.2021

- Determines free space better by checking free and purgeable space (partial fix for #152; thanks to Pico in MacAdmins Slack).
- Uses exit traps to clean up after all abnormal exits (fixes #140, #141; thanks to @ryangball).
- Adds `-nobrowse` to `hdiutil` to prevent mounted images appearing on the desktop (thanks to @ryangball).
- Allows 5 password attempts (fixes #159).
- Adds dialog to show how much time is left in the power check (#144; thanks to @dan-snelson).
- Some dialog changes, to replace the word "reinstall", which some people have found confusing, with "install" (addresses #149).
- Changed log location to the `$workdir` so that it persists after an upgrade, and also so it is wiped if using the `--cleanup-after-use` option (fixes #161).
- Remove check for membership of `staff` group for Apple Silicon Macs, since Volume Ownership is already checked it's not necessary, and was preventing non-admin AD users from proceeding (fixes #166).
- Re-order some initial statements to ensure that the chosen $workdir has been created before DEPNotify is downloaded and the log file is determined (fixes #165).
- Some minot changes to the Dutch translation (addresses #164, thanks @Alitekawi).

## [24.1]

27.10.2021

- Script now exits if an incorrect password is entered (partially fixes #136).
- Makefile uses `curl` to obtain DEPNotify.app without adding a quarantine bit (fixes #138).
- Fixes for certain workflows involving the `--fetch-full-installer` (#140) and `--pkg` (#141) options.
- Fixed `--user` option, which was not reading in the given user (#142, thanks @chymb).

## [24.0]

25.10.2021

- Removed the "0." from the version, as it's arbitrary and meaningless.
- `--seed` is now analogous to `--seedprogram`.
- New `--cleanup-after-use` option to delete the entire working directory after use (#131).
- `--move` will now move the installer even when using `--erase` or `--reinstall`.
- `--update` option now honours `--beta` and `--seed` options.
- The `--depnotify` option will download DEPNotify.app if it's not already installed.
- Fixed a problem with the `osascript` dialog when downloading an installer.
- Makefile now includes `depnotify` and `nopython` methods. `depnotify` bundles DEPNotify.app into the package, and expects `DEPNotify.zip` in the root of the cloned repo - must be copied there. `nopython` omits the relocatable-python framework (and also omits DEPNotify.app).
- Updated SHA key of `installinstallmacos.py` to reflect merged in upstream changes (updated software catalog URL for macOS 12).

## [0.23.0]

21.10.2021

- The package now includes a relocatable python installation (version 3.9.5) for use with `installinstallmacos.py`. This replaces the reliance on the macOS python2.7 distribution.
- For standalone script runs, erase-install.sh will now check for an existing relocatable python or MacAdmins Python installation. If neither exists, and `--no-curl` is not set, the script will download and install the minimum MacAdmins Python signed package, for use with `installinstallmacos.py`. If `--no-curl` is set, the script will fall back to python 2.
- If `installinstallmacos.py` is downloaded using curl, it is now checked against a defined SHA256 checksum. Note: this is calculated using the command: `shasum -a 256 installinstallmacos.py | cut -d' ' -f1`.
- Add download progress information to the DEPNotify bar (#127, thanks @andredb90, addresses #116).
- Rationalised version comparisons in the code from 3 to 1.

## [0.22.0]

01.10.2021

- Add preparation progress information to the DEPNotify bar (#122, thanks @andredb90).
- SIP check only checks for partial SIP enablement (#110, thanks @anverhousseini).
- New `--preinstall-command` option to run a command prior to the beginning of the `startosinstall` run (thanks Fredrik Virding for the idea).
- Fix build version comparisons (this affected macOS 11.6) (#124, thanks @boberito)
- Allow use of `--confirm` option for reinstallation (#123)
- Improve version comparisons in `check_newer_available` function (should improve `--update` reliability)
- Fix erase or reinstall from a InstallAssistant package if it has not already been extracted with the `--move` option (#111).

## [0.21.0]

20.07.2021

- Add French translation (thanks @Darkomen78).
- Fix version for which `--allowremoval` is set when doing a reinstall (thanks @anverhousseini).
- Kill DEPNotify in places where jamfHelper is killed (#106, thanks @julienvs).
- Added '$script_name' variable - if you want to change the script name, the echo statements will reflect this value rather than 'erase-install'.
- Added `--clear-cache-only` option, which works in conjunction with `--overwrite` or `--update` to perform the removal of cached installers but then quit rather than carry on with any further workflow (#105).
- Added a more verbose message that `--test-run` has been implemented (#93).

## [0.20.1]

12.05.2021

- The Cancel button is now default in the Confirm dialog when not using jamfHelper or DEPNotify. Note that DEPNotify only offers one button so we cannot provide a straightforward Cancel button.
- The contents of the `README.md` have been replaced with a wiki.

## [0.20.0]

07.05.2021

- `--depnotify` option. Uses DEPNotify instead of jamfHelper, if it is installed.
- `--no-jamfhelper` option. Ignores the jamfHelper installation. Useful for testing the `osascript` dialogs.

## [0.19.2]

26.04.2021

- Another fix to the check that `--fetch-full-installer` can be used.
- Edited Dutch localizations (thanks to Thijs Vught)

## [0.19.1]

17.04.2021

- Fix for check that `--fetch-full-installer` can be used.
- Dutch localizations (thanks to Thijs Vught)

## [0.19.0]

07.04.2021

- Output from erase-install.sh is now written to `/var/log/erase-install.sh` in addition to `stdout`.
- Checks that the supplied user is an admin when performing `--eraseinstall` on M1, which appears to be a requirement (not for `startosinstall` without `--eraseinstall`). If it is not, it promotes the user to admin.
- Checks that the supplied user is a Volume Owner on M1 (rather than merely having a Secure Token)
- Runs `diskutil apfs updatePreboot /` prior to `startosinstall` to (experimentally) address a problem seen by some user accounts that were promoted using `Privileges.app`.
- Adds localization for osascript dialogs

## [0.18.0]

10.03.2021

- Add `--check-power` option. Set this to check for AC power. Also `--power-wait-limit` sets a time limit to wait for power (default is 60 seconds).
- Merge in upstream changes to `installinstallmacos.py`. This improves download resumption.

## [0.17.4]

03.03.2021

- Default minimum drive space now set to 45GB, but can now be overridden with the `--min-drive-space NN` option.
- Fixed the `--confirm` option.
- Improved the `--help` output with more recent keys.

## [0.17.3]

20.01.2021

- For Catalina and earlier, do OS validation only as far as the minor release. This allows for the mismatch between advertised build and `DTSDKBuild` (fixes Issue #53).
- Fix for when `VolumeName` is not `Macintosh HD` or any two-word name (fixes Issue #58).
- Added exit 1 code if script exists due to not successfully downloading an installer (fixes Issue #52).
- Increase munimum disk space required to 30GB, which aligns better Apple's recommendation for macOS Big Sur (see [HT211238](https://support.apple.com/en-us/HT211238)).

## [0.17.2]

06.01.2021

- Testing moving `caffeinate` to the end of the script but using a second `--pidtosignal` argument in `startosinstall` to kill caffeinate. It is not documented that `--pidtosignal` can be called multiple times, so this is experimental, but seems necessary on Big Sur as the "preparing upgrade" step is much longer than with previous OSs.

## [0.17.1]

05.01.2021

- Added `--test-run` option which runs everything except the `startosinstall` command. Useful for testing new workflows.
- Moved the prompt for user details for Apple Silicon Macs up the script so users don't get prompted later.
- No longer checks to see if the user is an administrator as this is apparently not a criterion - only Secure Token matters.
- Bug fix: remove alignment flags in the jamfHelper commands to solve a product issue with jamfHelper on Apple Silicon Macs.

## [0.17.0]

15.12.2020

- New `--current-user` option to use the current logged in user for `startosinstall` authorisation on M1/DTK Macs.
- New `--user` option to specify a user for `startosinstall` authorisation on M1/DTK Macs.
- Now checks whether the specified user is an administrator.
- Now checks whether the specified user has a Secure Token.
- Now checks if the given password is correct.
- New `--no-fs` option for replacing the full-screen display with a utility window (for testing purposes).
- Now quits `caffeinate` before beginning `startosinstall`.
- Now correctly identifies Apple Silicon Mac Device IDs for compatibility checks.
- Now gets the installer version from `/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml` as this is a more reliable build number than the one in `Info.plist`.
- Now makes more reliable version comparisons using `BuildVersion` by splitting the check into more sections (`AABCCDDE` instead of `AABCCCCD`).
- Script version number is now displayed when running the script. I just have to remember to update it...
- added `--list-full-installers` option which runs `softwareupdate --list-full-installers` according to the seedprogram selected.
- `test-erase-install.sh` script is now included in the installer package.

## [0.16.1]

10.12.2020

- Bug fix: `--auto` was being incorrectly assigned when using `--os`, `--build` etc.

## [0.16.0]

10.12.2020

- Added the `--pkg` option allowing the download of an `InstallAssistant` package, utilising an update alresdy made to the `installinstallmacos.py` fork. For Big Sur or greater only. This will probably need some more error checking.
- Added the `--keep-pkg` option which prevents the deletion of the package if the `--move` option is used to extract the package to `/Applications`. By default, the package will be deleted on successful extraction.
- Added the `--force-curl` and `--no-curl` options, allowing the control of whether to download `installinstallmacos.py`. This is in anticipation of a Makefile and package release of `erase-install.sh`.
- Added `Makefile`. This allows you to build a self-contained package containing `erase-install.sh` and `installinstallmacos.py` so that curl is not used during the run of `erase-install.sh` to update `installinstallmacos.py`. This requires `munkipkg` and expects to find the `grahampugh` fork of `installinstallmacos.py` in `../macadmins-scripts`. Make sure you don't bundle in Greg Neagle's version of `installinstallmacos.py` inadvertently (or this script will fail). A package will be provided on GitHub for this and subsequent versions. Note that `erase-install.sh` is installed into `/Library/Management/erase-install`. I deliberately have not put `erase-install.sh` into the PATH.
- Added the `--user` and `--stdinpass` arguments when running on a Silicon Mac. Silicon Macs require an admin user and password to run `startosinstall`.
- Now treats `10.x` or `11`+ as major versions for OS comparisons.
- Fix in `installinstallmacos.py` for `os` comparisons failing where no Version is provided from the catalog.

## [0.15.6]

20.11.2020

- Fixed comparison of build numbers when checking the installed build is newer than the build in the downloaded installer.

## [0.15.5]

07.10.2020

- Version comparisons are now done based on `BuildVersion` instead of `ProductVersion` so as not to rely on Major/Minor/Point comparisons (thanks to Greg Neagle's MacSysAdmin 2020 presentation about Big Sur for tips on this).
- code clean up using ShellCheck.

## [0.15.4]

31.07.2020

- Added `--pythonpath` option so that you can select a different python with which to run `installinstallmacos.py`. Default is `$(which python)`.
- `installinstallmacos.py` now has a `--warnings` option about whether to show the Notes/Warnings in the list output or not. This has been hard-coded into `erase-install.sh` to maintain current behaviour.

## [0.15.3]

22.07.2020

- Fixed another small piece of failed logic around the check for whether there is already an installer which was finding other apps with `macOS` in the name. Now, only apps with `Install macOS*.app` will be found.

## [0.15.2]

14.07.2020

- Fixed some failed logic around the check for whether there is already an installer in the `/Applications` folder which was erroneously also looking in other locations.

## [0.15.1]

23.06.2020

- Parameters can now be supplied as `--argument value` as an alternative to `--argument=value` to provide more consistency with the included tools (`installinstallmacos.py` and `softwareupdate`).

## [0.15.0]

09.06.2020

- Adds `--allowremoval` option to the `startosinstall` command by default. This is an undocumented flag which is required under certain circumstances where there are backup files on the system disk.

## [0.14.0]

06.05.2020

- Adds `--replace_invalid` option for the option to overwrite a cached installer if it is not valid for use with `--erase` or `--reinstall`.
- Adds `--update` option for the option to overwrite a cached installer if a newer installer is available.

## [0.13.0]

04.05.2020

- Adds `--preservecontainer` option for workflows that need to retain a container when performing `eraseinstall`.
- Adds additional flags to `caffeinate` to attempt to more robustly prevent device sleeping.
- Fix for missing heading in the full screen display of the `--reinstall` option.
- Added a test script `tests/test-erase-install.sh` for testing out functionality.

## [0.12.1]

14.04.2020

- Use `--forcequitapps` when _using_ the macOS Catalina installer, rather than just when _running_ on a macOS Catalina client (issue #25).

## [0.12.0]

13.02.2020

- Removed downloaded OS validity check for modes where the installer is not required for reinstall or eraseinstall, to prevent unnecessary exit failures.
- Fixed a problem preveting `--move` from working when overwriting a valid installer.
- Other small bugfixes.

## [0.11.1]

03.02.2020

- Restricted the add forcequitapps install_args option to macOS 10.15 or greater, as this is not functional with older versions (#35). Thanks to '@ahousseini' for the contribution.

## [0.11.0]

22.01.2020

- Added the `--sameos` option, so you can have a single command which will always try to reinstall whatever macOS (major) version is currently installed on the host.

## [0.10.1]

11.12.2019

- Removed check that a user is logged in before proceeding with startosinstall - apparently not necessary after all, and caused at least one user's workflow to break (#33).

## [0.10.0]

27.11.2019

- Add a check that there is enough disk space before proceeding
- Added --forcequitapps argument for 10.15 and above
- Check that a user is logged in before proceeding with startosinstall
- Improved find commands when checking that there is a mounted installer
- Improved German descriptions for reinstallation
- Improved checks for successful downloads from the --fetch_full_installer option

Thanks to '@ahousseini' for various contributions to this release

## [0.9.1]

15.11.2019

- Move a comment that states that --fetch-full-installer is available to the correct place (#31)

## [0.9.0]

07.10.2019

- Added support for `softwareupdate --fetch-full-installer` and `seedutil` for clients running macOS 10.15 or greater.

## [0.8.0]

27.09.2019

- Fixed caffeinate (forgot to make it a background process)
- Added 'Confirm' option for erasing. Thanks to '@ryan-alectrona' for the contribution.

## [0.7.1]

26.09.2019

- Added caffeinate to the script to prevent the computer going to sleep during long download phases etc.

## [0.7.0]

12.07.2019

- Added `--beta` option.
- Changed behaviour of `--os`, `--version` and auto (i.e. no flag) options to get the latest rather than earliest valid build.
- Removed `install-macos.sh` script. Use `erase-install.sh` with `--reinstall` option instead.

## [0.6.0]

19.06.2019

- Added `--reinstall` option, which obsoletes the `install-macos.sh` script.

## [0.5.0]

16.04.2019

- Bug fix for empty extra packages folder.  
  Thanks to '@Avartharian' for contributions
- Added `--catalogurl` and `--seedprogram` options

## [0.4.0]

02.04.2019

- Added localisation of Jamf Helper messages.  
  Thanks to '@ahousseini' for contributions
- Added `--os`, `--path`, `--extras`, `--list` options.  
  Thanks to '@mark lamont' for contributions

## [0.3.2]

13.12.2018

- Bug fix for `--build` option, and for exiting gracefully when nothing is downloaded.

## [0.3.1]

21.09.2018

- Added ability to specify a macOS version.
- Fixed the `--overwrite` flag.
- Added ability to specify a build in the parameters, and we now clear out the cached content.

## [0.3.0]

03.09.2018

- Additional and amended options for selecting non-standard builds.

## [0.2.0]

09.07.2018

- Automatically selects a non-beta installer.

## 0.1.0

29.03.2018

- Initial version. Expects a manual choice of installer from `installinstallmacos.py`.

[untagged]: https://github.com/grahampugh/erase-install/compare/v32.0...HEAD
[32.0]: https://github.com/grahampugh/erase-install/compare/v31.0...v32.0
[31.0]: https://github.com/grahampugh/erase-install/compare/v30.2...v31.0
[30.2]: https://github.com/grahampugh/erase-install/compare/v30.1...v30.2
[30.1]: https://github.com/grahampugh/erase-install/compare/v30.0...v30.1
[30.0]: https://github.com/grahampugh/erase-install/compare/v29.1...v30.0
[29.1]: https://github.com/grahampugh/erase-install/compare/v29.0...v29.1
[29.0]: https://github.com/grahampugh/erase-install/compare/v28.1...v29.0
[28.1]: https://github.com/grahampugh/erase-install/compare/v28.0...v28.1
[28.0]: https://github.com/grahampugh/erase-install/compare/v27.3...v28.0
[27.3]: https://github.com/grahampugh/erase-install/compare/v27.2...v27.3
[27.2]: https://github.com/grahampugh/erase-install/compare/v27.1...v27.2
[27.1]: https://github.com/grahampugh/erase-install/compare/v27.0...v27.1
[27.0]: https://github.com/grahampugh/erase-install/compare/v26.2...v27.0
[26.2]: https://github.com/grahampugh/erase-install/compare/v26.1...v26.2
[26.1]: https://github.com/grahampugh/erase-install/compare/v26.0...v26.1
[26.0]: https://github.com/grahampugh/erase-install/compare/v25.0...v26.0
[25.0]: https://github.com/grahampugh/erase-install/compare/v24.1...v25.0
[24.1]: https://github.com/grahampugh/erase-install/compare/v24.0...v24.1
[24.0]: https://github.com/grahampugh/erase-install/compare/v0.23.0...v24.0
[0.23.0]: https://github.com/grahampugh/erase-install/compare/v0.22.0...v0.23.0
[0.22.0]: https://github.com/grahampugh/erase-install/compare/v0.21.0...v0.22.0
[0.21.0]: https://github.com/grahampugh/erase-install/compare/v0.20.1...v0.21.0
[0.20.1]: https://github.com/grahampugh/erase-install/compare/v0.20.0...v0.20.1
[0.20.0]: https://github.com/grahampugh/erase-install/compare/v0.19.2...v0.20.0
[0.19.2]: https://github.com/grahampugh/erase-install/compare/v0.19.1...v0.19.2
[0.19.1]: https://github.com/grahampugh/erase-install/compare/v0.19.0...v0.19.1
[0.19.0]: https://github.com/grahampugh/erase-install/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/grahampugh/erase-install/compare/v0.17.4...v0.18.0
[0.17.4]: https://github.com/grahampugh/erase-install/compare/v0.17.3...v0.17.4
[0.17.3]: https://github.com/grahampugh/erase-install/compare/v0.17.2...v0.17.3
[0.17.2]: https://github.com/grahampugh/erase-install/compare/v0.17.1...v0.17.2
[0.17.1]: https://github.com/grahampugh/erase-install/compare/v0.17.0...v0.17.1
[0.17.0]: https://github.com/grahampugh/erase-install/compare/v0.16.1...v0.17.0
[0.16.1]: https://github.com/grahampugh/erase-install/compare/v0.16.0...v0.16.1
[0.16.0]: https://github.com/grahampugh/erase-install/compare/v0.15.6...v0.16.0
[0.15.6]: https://github.com/grahampugh/erase-install/compare/v0.15.5...v0.15.6
[0.15.5]: https://github.com/grahampugh/erase-install/compare/v0.15.4...v0.15.5
[0.15.4]: https://github.com/grahampugh/erase-install/compare/v0.15.3...v0.15.4
[0.15.3]: https://github.com/grahampugh/erase-install/compare/v0.15.2...v0.15.3
[0.15.2]: https://github.com/grahampugh/erase-install/compare/v0.15.1...v0.15.2
[0.15.1]: https://github.com/grahampugh/erase-install/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/grahampugh/erase-install/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/grahampugh/erase-install/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/grahampugh/erase-install/compare/v0.12.1...v0.13.0
[0.12.1]: https://github.com/grahampugh/erase-install/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/grahampugh/erase-install/compare/v0.11.1...v0.12.0
[0.11.1]: https://github.com/grahampugh/erase-install/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/grahampugh/erase-install/compare/v0.10.1...v0.11.0
[0.10.1]: https://github.com/grahampugh/erase-install/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/grahampugh/erase-install/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/grahampugh/erase-install/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/grahampugh/erase-install/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/grahampugh/erase-install/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/grahampugh/erase-install/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/grahampugh/erase-install/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/grahampugh/erase-install/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/grahampugh/erase-install/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/grahampugh/erase-install/compare/v0.3.2...v0.4.0
[0.3.2]: https://github.com/grahampugh/erase-install/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/grahampugh/erase-install/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/grahampugh/erase-install/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/grahampugh/erase-install/compare/v0.1.0...v0.2.0
