# CHANGELOG

## [Untagged]

No date

## [0.22.0]

19.09.2021

-   Add preparation progress information to the DEPNotify bar (#122, thanks @andredb90).
-   SIP check only checks for partial SIP enablement (#110, thanks @anverhousseini).
-   New `--preinstall-command` option to run a command prior to the beginning of the `startosinstall` run (thanks Fredrik Virding for the idea).
-   Fix build version comparisons (this affected macOS 11.6) (#124, thanks @boberito)
-   Allow use of `--confirm` option for reinstallation (#123)
-   Improve version comparisons in `check_newer_available` function (should improve `--update` reliability)

## [0.21.0]

20.07.2021

-   Add French translation (thanks @Darkomen78).
-   Fix version for which `--allowremoval` is set when doing a reinstall (thanks @anverhousseini).
-   Kill DEPNotify in places where jamfHelper is killed (#106, thanks @julienvs).
-   Added '$script_name' variable - if you want to change the script name, the echo statements will reflect this value rather than 'erase-install'.
-   Added `--clear-cache-only` option, which works in conjunction with `--overwrite` or `--update` to perform the removal of cached installers but then quit rather than carry on with any further workflow (#105).
-   Added a more verbose message that `--test-run` has been implemented (#93).

## [0.20.1]

12.05.2021

-   The Cancel button is now default in the Confirm dialog when not using jamfHelper or DEPNotify. Note that DEPNotify only offers one button so we cannot provide a straightforward Cancel button.
-   The contents of the `README.md` have been replaced with a wiki.

## [0.20.0]

07.05.2021

-   `--depnotify` option. Uses DEPNotify instead of jamfHelper, if it is installed.
-   `--no-jamfhelper` option. Ignores the jamfHelper installation. Useful for testing the `osascript` dialogs.

## [0.19.2]

26.04.2021

-   Another fix to the check that `--fetch-full-installer` can be used.
-   Edited Dutch localizations (thanks to Thijs Vught)

## [0.19.1]

17.04.2021

-   Fix for check that `--fetch-full-installer` can be used.
-   Dutch localizations (thanks to Thijs Vught)

## [0.19.0]

07.04.2021

-   Output from erase-install.sh is now written to `/var/log/erase-install.sh` in addition to `stdout`.
-   Checks that the supplied user is an admin when performing `--eraseinstall` on M1, which appears to be a requirement (not for `startosinstall` without `--eraseinstall`). If it is not, it promotes the user to admin.
-   Checks that the supplied user is a Volume Owner on M1 (rather than merely having a Secure Token)
-   Runs `diskutil apfs updatePreboot /` prior to `startosinstall` to (experimentally) address a problem seen by some user accounts that were promoted using `Privileges.app`.
-   Adds localization for osascript dialogs

## [0.18.0]

10.03.2021

-   Add `--check-power` option. Set this to check for AC power. Also `--power-wait-limit` sets a time limit to wait for power (default is 60 seconds).
-   Merge in upstream changes to `installinstallmacos.py`. This improves download resumption.

## [0.17.4]

03.03.2021

-   Default minimum drive space now set to 45GB, but can now be overridden with the `--min-drive-space NN` option.
-   Fixed the `--confirm` option.
-   Improved the `--help` output with more recent keys.

## [0.17.3]

20.01.2021

-   For Catalina and earlier, do OS validation only as far as the minor release. This allows for the mismatch between advertised build and `DTSDKBuild` (fixes Issue #53).
-   Fix for when `VolumeName` is not `Macintosh HD` or any two-word name (fixes Issue #58).
-   Added exit 1 code if script exists due to not successfully downloading an installer (fixes Issue #52).
-   Increase munimum disk space required to 30GB, which aligns better Apple's recommendation for macOS Big Sur (see [HT211238](https://support.apple.com/en-us/HT211238)).

## [0.17.2]

06.01.2021

-   Testing moving `caffeinate` to the end of the script but using a second `--pidtosignal` argument in `startosinstall` to kill caffeinate. It is not documented that `--pidtosignal` can be called multiple times, so this is experimental, but seems necessary on Big Sur as the "preparing upgrade" step is much longer than with previous OSs.

## [0.17.1]

05.01.2021

-   Added `--test-run` option which runs everything except the `startosinstall` command. Useful for testing new workflows.
-   Moved the prompt for user details for Apple Silicon Macs up the script so users don't get prompted later.
-   No longer checks to see if the user is an administrator as this is apparently not a criterion - only Secure Token matters.
-   Bug fix: remove alignment flags in the jamfHelper commands to solve a product issue with jamfHelper on Apple Silicon Macs.

## [0.17.0]

15.12.2020

-   New `--current-user` option to use the current logged in user for `startosinstall` authorisation on M1/DTK Macs.
-   New `--user` option to specify a user for `startosinstall` authorisation on M1/DTK Macs.
-   Now checks whether the specified user is an administrator.
-   Now checks whether the specified user has a Secure Token.
-   Now checks if the given password is correct.
-   New `--no-fs` option for replacing the full-screen display with a utility window (for testing purposes).
-   Now quits `caffeinate` before beginning `startosinstall`.
-   Now correctly identifies Apple Silicon Mac Device IDs for compatibility checks.
-   Now gets the installer version from `/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml` as this is a more reliable build number than the one in `Info.plist`.
-   Now makes more reliable version comparisons using `BuildVersion` by splitting the check into more sections (`AABCCDDE` instead of `AABCCCCD`).
-   Script version number is now displayed when running the script. I just have to remember to update it...
-   added `--list-full-installers` option which runs `softwareupdate --list-full-installers` according to the seedprogram selected.
-   `test-erase-install.sh` script is now included in the installer package.

## [0.16.1]

10.12.2020

-   Bug fix: `--auto` was being incorrectly assigned when using `--os`, `--build` etc.

## [0.16.0]

10.12.2020

-   Added the `--pkg` option allowing the download of an `InstallAssistant` package, utilising an update alresdy made to the `installinstallmacos.py` fork. For Big Sur or greater only. This will probably need some more error checking.
-   Added the `--keep-pkg` option which prevents the deletion of the package if the `--move` option is used to extract the package to `/Applications`. By default, the package will be deleted on successful extraction.
-   Added the `--force-curl` and `--no-curl` options, allowing the control of whether to download `installinstallmacos.py`. This is in anticipation of a Makefile and package release of `erase-install.sh`.
-   Added `Makefile`. This allows you to build a self-contained package containing `erase-install.sh` and `installinstallmacos.py` so that curl is not used during the run of `erase-install.sh` to update `installinstallmacos.py`. This requires `munkipkg` and expects to find the `grahampugh` fork of `installinstallmacos.py` in `../macadmins-scripts`. Make sure you don't bundle in Greg Neagle's version of `installinstallmacos.py` inadvertently (or this script will fail). A package will be provided on GitHub for this and subsequent versions. Note that `erase-install.sh` is installed into `/Library/Management/erase-install`. I deliberately have not put `erase-install.sh` into the PATH.
-   Added the `--user` and `--stdinpass` arguments when running on a Silicon Mac. Silicon Macs require an admin user and password to run `startosinstall`.
-   Now treats `10.x` or `11`+ as major versions for OS comparisons.
-   Fix in `installinstallmacos.py` for `os` comparisons failing where no Version is provided from the catalog.

## [0.15.6]

20.11.2020

-   Fixed comparison of build numbers when checking the installed build is newer than the build in the downloaded installer.

## [0.15.5]

07.10.2020

-   Version comparisons are now done based on `BuildVersion` instead of `ProductVersion` so as not to rely on Major/Minor/Point comparisons (thanks to Greg Neagle's MacSysAdmin 2020 presentation about Big Sur for tips on this).
-   code clean up using ShellCheck.

## [0.15.4]

31.07.2020

-   Added `--pythonpath` option so that you can select a different python with which to run `installinstallmacos.py`. Default is `$(which python)`.
-   `installinstallmacos.py` now has a `--warnings` option about whether to show the Notes/Warnings in the list output or not. This has been hard-coded into `erase-install.sh` to maintain current behaviour.

## [0.15.3]

22.07.2020

-   Fixed another small piece of failed logic around the check for whether there is already an installer which was finding other apps with `macOS` in the name. Now, only apps with `Install macOS*.app` will be found.

## [0.15.2]

14.07.2020

-   Fixed some failed logic around the check for whether there is already an installer in the `/Applications` folder which was erroneously also looking in other locations.

## [0.15.1]

23.06.2020

-   Parameters can now be supplied as `--argument value` as an alternative to `--argument=value` to provide more consistency with the included tools (`installinstallmacos.py` and `softwareupdate`).

## [0.15.0]

09.06.2020

-   Adds `--allowremoval` option to the `startosinstall` command by default. This is an undocumented flag which is required under certain circumstances where there are backup files on the system disk.

## [0.14.0]

06.05.2020

-   Adds `--replace_invalid` option for the option to overwrite a cached installer if it is not valid for use with `--erase` or `--reinstall`.
-   Adds `--update` option for the option to overwrite a cached installer if a newer installer is available.

## [0.13.0]

04.05.2020

-   Adds `--preservecontainer` option for workflows that need to retain a container when performing `eraseinstall`.
-   Adds additional flags to `caffeinate` to attempt to more robustly prevent device sleeping.
-   Fix for missing heading in the full screen display of the `--reinstall` option.
-   Added a test script `tests/test-erase-install.sh` for testing out functionality.

## [0.12.1]

14.04.2020

-   Use `--forcequitapps` when _using_ the macOS Catalina installer, rather than just when _running_ on a macOS Catalina client (issue #25).

## [0.12.0]

13.02.2020

-   Removed downloaded OS validity check for modes where the installer is not required for reinstall or eraseinstall, to prevent unnecessary exit failures.
-   Fixed a problem preveting `--move` from working when overwriting a valid installer.
-   Other small bugfixes.

## [0.11.1]

03.02.2020

-   Restricted the add forcequitapps install_args option to macOS 10.15 or greater, as this is not functional with older versions (#35). Thanks to '@ahousseini' for the contribution.

## [0.11.0]

22.01.2020

-   Added the `--sameos` option, so you can have a single command which will always try to reinstall whatever macOS (major) version is currently installed on the host.

## [0.10.1]

11.12.2019

-   Removed check that a user is logged in before proceeding with startosinstall - apparently not necessary after all, and caused at least one user's workflow to break (#33).

## [0.10.0]

27.11.2019

-   Add a check that there is enough disk space before proceeding
-   Added --forcequitapps argument for 10.15 and above
-   Check that a user is logged in before proceeding with startosinstall
-   Improved find commands when checking that there is a mounted installer
-   Improved German descriptions for reinstallation
-   Improved checks for successful downloads from the --fetch_full_installer option

Thanks to '@ahousseini' for various contributions to this release

## [0.9.1]

15.11.2019

-   Move a comment that states that --fetch-full-installer is available to the correct place (#31)

## [0.9.0]

07.10.2019

-   Added support for `softwareupdate --fetch-full-installer` and `seedutil` for clients running macOS 10.15 or greater.

## [0.8.0]

27.09.2019

-   Fixed caffeinate (forgot to make it a background process)
-   Added 'Confirm' option for erasing. Thanks to '@ryan-alectrona' for the contribution.

## [0.7.1]

26.09.2019

-   Added caffeinate to the script to prevent the computer going to sleep during long download phases etc.

## [0.7.0]

12.07.2019

-   Added `--beta` option.
-   Changed behaviour of `--os`, `--version` and auto (i.e. no flag) options to get the latest rather than earliest valid build.
-   Removed `install-macos.sh` script. Use `erase-install.sh` with `--reinstall` option instead.

## [0.6.0]

19.06.2019

-   Added `--reinstall` option, which obsoletes the `install-macos.sh` script.

## [0.5.0]

16.04.2019

-   Bug fix for empty extra packages folder.  
    Thanks to '@Avartharian' for contributions
-   Added `--catalogurl` and `--seedprogram` options

## [0.4.0]

02.04.2019

-   Added localisation of Jamf Helper messages.  
    Thanks to '@ahousseini' for contributions
-   Added `--os`, `--path`, `--extras`, `--list` options.  
    Thanks to '@mark lamont' for contributions

## [0.3.2]

13.12.2018

-   Bug fix for `--build` option, and for exiting gracefully when nothing is downloaded.

## [0.3.1]

21.09.2018

-   Added ability to specify a macOS version.
-   Fixed the `--overwrite` flag.
-   Added ability to specify a build in the parameters, and we now clear out the cached content.

## [0.3.0]

03.09.2018

-   Additional and amended options for selecting non-standard builds.

## [0.2.0]

09.07.2018

-   Automatically selects a non-beta installer.

## 0.1.0

29.03.2018

-   Initial version. Expects a manual choice of installer from `installinstallmacos.py`.

[untagged]: https://github.com/grahampugh/erase-install/compare/v0.22.0...HEAD
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
