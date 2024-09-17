#!/bin/zsh --no-rcs
# shellcheck shell=bash
# shellcheck disable=SC2001
# this is to use sed in the case statements
# shellcheck disable=SC2034,SC2296
# these are due to the dynamic variable assignments used in the localization strings

: <<DOC
==============================================================================
erase-install.sh
==============================================================================
by Graham Pugh

WARNING. This is a self-destruct script. Do not try it out on your own device!

See README.md and the GitHub repo's Wiki for details on use.

It is recommended to use the package installer of this script. It contains 
swiftDialog and mist, which are required for most of the use-cases of this script.

This script can, however, also be run standalone.
It will download and install swiftDialog if needed and not found.
It will also download mist if it is not found.
Suppress the downloads with the --no-curl option.

Requirements:
- macOS 11+ (for use on older versions of macOS, download version 27.3 of erase-install.sh)
- Device file system is APFS
DOC

# =============================================================================
# Variables 
# =============================================================================

# script name
script_name="erase-install"
pkg_label="com.github.grahampugh.erase-install"

# Version of this script
version="36.0"

# Directory in which to place the macOS installer. Overridden with --path
installer_directory="/Applications"

# Default working directory (may be overridden by the --workdir parameter)
workdir="/Library/Management/erase-install"

# Default logdir
logdir="/Library/Management/erase-install/log"

# mist tool
mist_bin="/usr/local/bin/mist"

# Required mist-cli version
# This ensures a compatible mist version is used if not using the package installer
mist_tag_required="v2.1.1"

# Required swiftDialog version
# This ensures a compatible swiftDialog version is used if not using the package installer
swiftdialog_tag_required="v2.5.2"

# Required swiftDialog version for macOS 11
# This ensures a compatible swiftDialog version is used if not using the package installer
swiftdialog_bigsur_tag_required="v2.2.1"

# swiftDialog variables
dialog_app="/Library/Application Support/Dialog/Dialog.app"
dialog_bin="/usr/local/bin/dialog"
dialog_log=$(/usr/bin/mktemp /var/tmp/dialog.XXX)
dialog_output="/var/tmp/dialog.json"

# swiftDialog icons
dialog_dl_icon="/System/Library/PrivateFrameworks/SoftwareUpdate.framework/Versions/A/Resources/SoftwareUpdate.icns"
dialog_confirmation_icon="/System/Applications/System Settings.app"
dialog_warning_icon="SF=xmark.circle,colour=red"
dialog_fmm_icon="/System/Library/PrivateFrameworks/AOSUI.framework/Versions/A/Resources/findmy.icns"
dialog_icon_size="128"

# default app and package names for mist
default_downloaded_app_name="Install %NAME%.app"
default_downloaded_pkg_name="InstallAssistant-%VERSION%-%BUILD%.pkg"
default_downloaded_pkg_id="com.apple.InstallAssistant.%VERSION%.%BUILD%.pkg"

# =============================================================================
# Functions 
# functions are listed alphabetically
# =============================================================================

# -----------------------------------------------------------------------------
# Open a dialog window to ask for the user's username and password.
# This is required on Apple Silicon Mac
# -----------------------------------------------------------------------------
ask_for_credentials() {
    # set the dialog command arguments
    get_default_dialog_args "utility"
    dialog_args=("${default_dialog_args[@]}")
    dialog_args+=(
        "--title"
        "${dialog_window_title}"
        "--icon"
        "${dialog_confirmation_icon}"
        "--overlayicon"
        "SF=key.fill"
        "--iconsize"
        "${dialog_icon_size}"
        "--textfield"
        "Username,prompt=$current_user"
        "--textfield"
        "Password,secure"
        "--button1text"
        "Continue"
        "--timer"
        "300"
        "--hidetimerbar"
    )
    if [[ "$erase" == "yes" ]]; then
        dialog_args+=(
            "--message"
            "${(P)dialog_erase_credentials}"
        )
    else
        dialog_args+=(
            "--message"
            "${(P)dialog_reinstall_credentials}"
        )
    fi
    if [[ $max_password_attempts != "infinite" ]]; then
        dialog_args+=("-2")
    fi

    # run the dialog command
    "$dialog_bin" "${dialog_args[@]}" 2>/dev/null > "$dialog_output"
}

# -----------------------------------------------------------------------------
# Dialogue to disable Find My Mac. 
# Called when --check-fmm option is used.
# Not used in --silent mode.
# -----------------------------------------------------------------------------
check_fmm() {
    # default Find My wait timer to 60 seconds
    if [[ ! $fmm_wait_timer ]]; then 
        fmm_wait_timer=300
    fi

    if ! nvram -xp | grep fmm-mobileme-token-FMM > /dev/null ; then
        writelog "[check_fmm] OK - Find My not enabled"
    elif [[ $silent ]]; then
        writelog "[check_fmm] ERROR - Find My enabled, cannot continue."
        echo
        exit 1
    else
        writelog "[check_fmm] WARNING - Find My enabled"
        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        # original icon: ${dialog_confirmation_icon}
        dialog_args+=(
            "--title"
            "${(P)dialog_fmm_title}"
            "--icon"
            "${dialog_confirmation_icon}"
            "--overlayicon"
            "${dialog_fmm_icon}"
            "--iconsize"
            "${dialog_icon_size}"
            "--message"
            "${(P)dialog_fmm_desc}"
            "--timer"
            "${fmm_wait_timer}"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null & sleep 0.1

        # now count down while checking if Find My has been disabled
        while [[ "$fmm_wait_timer" -gt 0 ]]; do
            if ! nvram -xp | grep fmm-mobileme-token-FMM > /dev/null ; then
                writelog "[check_fmm] OK - Find My not enabled"
                # quit dialog
                writelog "[check_fmm] Sending quit message to dialog log ($dialog_log)"
                echo "quit:" >> "$dialog_log"
                return
            fi
            sleep 1
            ((fmm_wait_timer--))
        done

        # quit dialog
        writelog "[check_fmm] Sending quit message to dialog log ($dialog_log)"
        echo "quit:" >> "$dialog_log"

        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        dialog_args+=(
            "--title"
            "${(P)dialog_fmm_title}"
            "--icon"
            "${dialog_confirmation_icon}"
            "--iconsize"
            "${dialog_icon_size}"
            "--overlayicon"
            "${dialog_fmm_icon}"
            "--message"
            "${(P)dialog_fmmenabled_desc}"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null

        writelog "[check_fmm] ERROR - Find My still enabled after waiting for ${fmm_wait_timer}s, cannot continue."
        echo
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Checks for active meetings.
# Function taken from installomator, function hasDisplaySleepAssertion
# Called when --check-activty option is used.
# -----------------------------------------------------------------------------
check_for_presentation_activity() {
    # Get the names of all apps with active display sleep assertions
    local apps
    apps="$(/usr/bin/pmset -g assertions | /usr/bin/awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ {gsub(/^.*\(/,"",$0); gsub(/\).*$/,"",$0); print};')"

    if [[ ! "$apps" ]]; then
        # No display sleep assertions detected
        writelog "[check_for_presentation_activity] No active meetings detected. Continuing."
        return
    fi

    # Create an array of apps that need to be ignored
    IGNORE_DND_APPS="caffeinate"
    local ignore_array=("${(@s/,/)IGNORE_DND_APPS}")

    for app in ${(f)apps}; do
        if (( ! ${ignore_array[(Ie)${app}]} )); then
            # Relevant app with display sleep assertion detected
            writelog "[check_for_presentation_activity] Active meeting detected (${app}). Exiting."
            exit 0
        fi
    done    
}

# -----------------------------------------------------------------------------
# Download mist if not present and not --silent mode
# -----------------------------------------------------------------------------
check_for_mist() {
    if [[ -f "$mist_bin" ]]; then
        # check mist version because older versions may not obtain a valid installer
        mist_version=$("$mist_bin" --version | head -n 1 | cut -d' ' -f1)
        if [[ v"$mist_version" == "$mist_tag_required" ]]; then
            writelog "[check_for_mist] mist-cli $mist_tag_required is installed ($mist_bin)"
            mist_is_compatible=1
        else
            writelog "[check_for_mist] mist-cli v$mist_version is installed ($mist_bin) - does not match required version $mist_tag_required"
            mist_is_compatible=0
        fi
    else
        writelog "[check_for_mist] mist-cli is not installed"
        mist_is_compatible=0
    fi
    if [[ $mist_is_compatible -ne 1 ]]; then
        if [[ ! $no_curl ]]; then
            writelog "[check_for_mist] Downloading mist-cli..."

            # obtain the download URL
            mist_api_url="https://api.github.com/repos/ninxsoft/mist-cli/releases"
            mist_download_url=$(/usr/bin/curl -sL -H "Accept: application/json" "$mist_api_url/tags/$mist_tag_required" | awk -F '"' '/browser_download_url/ { print $4; exit }')
            
            if /usr/bin/curl -L "$mist_download_url" -o "$workdir/mist-cli.pkg" ; then
                if installer -pkg "$workdir/mist-cli.pkg" -target / ; then
                    mist_is_compatible=1
                else
                    writelog "[check_for_mist] WARNING! mist-cli installation failed"
                fi
            fi
        fi
        # check it did actually get downloaded
        if [[ $mist_is_compatible -eq 1 ]]; then
            writelog "[check_for_mist] mist-cli $mist_tag_required is installed ($mist_bin)"
        elif [[ -f "$mist_bin" ]]; then
            writelog "[check_for_mist] WARNING! mist-cli v$mist_version is installed ($mist_bin) - does not match required version $mist_tag_required"
        else
            writelog "[check_for_mist] ERROR! Could not download mist-cli. Cannot continue."
            exit 1
        fi
    fi
}

# -----------------------------------------------------------------------------
# Download dialog if not present and not --silent mode
# -----------------------------------------------------------------------------
check_for_swiftdialog_app() {
    # swiftDialog 2.3 and higher are incompatible with macOS 11. Remove this version if present.
    if [[ -d "$dialog_app" && -f "$dialog_bin" ]]; then
        if ! is-at-least "12" "$system_version"; then 
            dialog_string=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Library/Application\ Support/Dialog/Dialog.app/Contents/Info.plist)
            dialog_minor_vers=$(cut -d. -f1,2 <<< "$dialog_string")
            if [[ $(echo "$dialog_minor_vers > 2.2" | bc) -eq 1 ]]; then
                writelog "[check_for_swiftdialog_app] swiftDialog v$dialog_string is installed but is not compatible with macOS $system_version. Removing v$dialog_string..."
                app_directory="/Library/Application Support/Dialog"
                bin_shortcut="/usr/local/bin/dialog"
                /bin/rm -rf "$app_directory" 
                /bin/rm -f "$bin_shortcut" /var/tmp/dialog.*
            fi
        fi
    fi

    # now check for any version of swiftDialog and download if not present
    if [[ -d "$dialog_app" && -f "$dialog_bin" ]]; then
        dialog_string=$("$dialog_bin" --version 2>/dev/null)
        dialog_minor_vers=$(cut -d. -f1,2 <<< "$dialog_string")
        writelog "[check_for_swiftdialog_app] swiftDialog v$dialog_string is installed ($dialog_app)"
    else
        if [[ ! $no_curl ]]; then
            if ! is-at-least "12" "$system_version"; then 
                # we need to get the older version of swiftDialog that is compatible with Big Sur
                swiftdialog_tag_required="$swiftdialog_bigsur_tag_required"
                writelog "[check_for_swiftdialog_app] Downloading swiftDialog for macOS $system_version..."
            else
                writelog "[check_for_swiftdialog_app] Downloading swiftDialog..."
            fi

            # obtain the download URL
            swiftdialog_api_url="https://api.github.com/repos/swiftDialog/swiftDialog/releases"
            dialog_download_url=$(/usr/bin/curl -sL -H "Accept: application/json" "$swiftdialog_api_url/tags/$swiftdialog_tag_required" | awk -F '"' '/browser_download_url/ { print $4; exit }')
            
            if /usr/bin/curl -L "$dialog_download_url" -o "$workdir/dialog.pkg" ; then
                if installer -pkg "$workdir/dialog.pkg" -target / ; then
                    dialog_string=$("$dialog_bin" --version)
                    dialog_minor_vers=$(cut -d. -f1,2 <<< "$dialog_string")
                else
                    writelog "[check_for_swiftdialog_app] swiftDialog installation failed"
                    exit 1
                fi
            else
                writelog "[check_for_swiftdialog_app] swiftDialog download failed"
                exit 1
            fi
        fi
        # check it did actually get downloaded
        if [[ -d "$dialog_app" && -f "$dialog_bin" ]]; then
            writelog "[check_for_swiftdialog_app] swiftDialog v$dialog_string is installed"
        else
            writelog "[check_for_swiftdialog_app] Could not download swiftDialog."
            exit 1
        fi
    fi

    # ensure log file is writable
    writelog "[check_for_swiftdialog_app] Creating dialog log ($dialog_log)..."
    /usr/bin/touch "$dialog_log"
    /usr/sbin/chown "${current_user}:wheel" "$dialog_log"
    /bin/chmod 666 "$dialog_log"
}

# -----------------------------------------------------------------------------
# Determine if the amount of free and purgable drive space is sufficient for 
# the upgrade to take place.
# The JavaScript osascript is used to give us the purgeable space as this is 
# not available via any shell commands (Thanks to Pico). 
# However, this does not work at the login window, so then we have to fall 
# back to using df -h, which will not include purgeable space.
# -----------------------------------------------------------------------------
check_free_space() {
    free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")

    if [[ ! "$free_disk_space" ]] || [[ "$free_disk_space" == 0 ]]; then
        # fall back to df if the above fails
        free_disk_space=$(df -Pk . | column -t | sed 1d | awk '{print $4}' | xargs -I{} expr {} / 1000000)
    fi

    # if there isn't enough space, then we show a failure message to the user
    if [[ $free_disk_space -ge $min_drive_space ]]; then
        writelog "[check_free_space] OK - $free_disk_space GB free/purgeable disk space detected"
    elif [[ $silent ]]; then
        writelog "[check_free_space] ERROR - $free_disk_space GB free/purgeable disk space detected"
        echo
        exit 1
    else
        writelog "[check_free_space] ERROR - $free_disk_space GB free/purgeable disk space detected"
        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        dialog_args+=(
            "--title"
            "${dialog_window_title}"
            "--icon"
            "${dialog_confirmation_icon}"
            "--iconsize"
            "${dialog_icon_size}"
            "--overlayicon"
            "SF=externaldrive.fill.badge.xmark,colour=red"
            "--message"
            "${(P)dialog_check_desc}"
            "--button1text"
            "${(P)dialog_cancel_button}"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Check the installer validity.
# The Build number in the app Info.plist is often older than the advertised 
# build number, so it's not a great check for checking the validity of the installer
# if we are running --erase, where we might want to be using the same build.
# Since macOS 11, the actual build number is found in the SharedSupport.dmg in 
# com_apple_MobileAsset_MacSoftwareUpdate.xml.
# For older OSs we include a fallback to the older, less accurate 
# Info.plist file.
# -----------------------------------------------------------------------------
check_installer_is_valid() {
    writelog "[check_installer_is_valid] Checking validity of $cached_installer_app."

    # first ensure that an installer is not still mounted from a previous run as it might 
    # interfere with the check
    [[ -d "/Volumes/Shared Support" ]] && diskutil unmount force "/Volumes/Shared Support"

    # now attempt to mount the installer and grab the build number from
    # com_apple_MobileAsset_MacSoftwareUpdate.xml
    if [[ -f "$cached_installer_app/Contents/SharedSupport/SharedSupport.dmg" ]]; then
        if hdiutil attach -quiet -noverify -nobrowse "$cached_installer_app/Contents/SharedSupport/SharedSupport.dmg" ; then
            writelog "[check_installer_is_valid] Mounting $cached_installer_app/Contents/SharedSupport/SharedSupport.dmg"
            sleep 1
            build_xml="/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
            if [[ -f "$build_xml" ]]; then
                writelog "[check_installer_is_valid] Using Build value from com_apple_MobileAsset_MacSoftwareUpdate.xml"
                installer_build=$(/usr/libexec/PlistBuddy -c "Print :Assets:0:Build" "$build_xml")

                # Also get the compatible device/board IDs of the installer and compare with the system device/board ID
                # 1. Grab device/board ID
                get_device_id
                # 2. Grab compatible device/board IDs from com_apple_MobileAsset_MacSoftwareUpdate
                compatible_device_ids=$(grep -A2 "SupportedDeviceModels" "$build_xml" | grep string | awk -F '<string>|</string>' '{ print $2 }')
                # 3. Check that 1 is in 2. 
                if [[ ($device_id && "$compatible_device_ids" == *"$device_id"*) || ($board_id && "$compatible_device_ids" == *"$board_id") ]]; then
                    writelog "[check_installer_is_valid] Installer is compatible with system"
                else
                    writelog "[check_installer_is_valid] ERROR: Installer is incompatible with system"
                    invalid_installer_found="yes"
                fi
            else
                writelog "[check_installer_is_valid] ERROR: com_apple_MobileAsset_MacSoftwareUpdate.xml not found. Check the mount point at /Volumes/Shared Support"
            fi
            # now we can unmount the dmg
            sleep 1
            diskutil unmount force "/Volumes/Shared Support"
        else
            writelog "[check_installer_is_valid] Mounting SharedSupport.dmg failed"
        fi
    else
    # if that fails, fallback to the method for 10.15 or less, which is less accurate
        writelog "[check_installer_is_valid] Using DTSDKBuild value from Info.plist"
        if [[ -f "$cached_installer_app/Contents/Info.plist" ]]; then
            installer_build=$( /usr/bin/defaults read "$cached_installer_app/Contents/Info.plist" DTSDKBuild )
        else
            writelog "[check_installer_is_valid] Installer Info.plist could not be found!"
        fi
    fi

    # bail out if we did not obtain a build number
    if [[ $installer_build ]]; then
        # compare the local system's build number with that of the installer app 
        # if current system is on a beta, we have to assume that this is older than a build number of the same minor version
        if /usr/bin/grep -e "[a-z]$" <<< "$system_build"; then
            # system is beta
            if /usr/bin/grep -e "[a-z]$" <<< "$installer_build"; then
                if ! is-at-least "$system_build" "$installer_build"; then
                    writelog "[check_installer_is_valid] Installer: $installer_build < System: $system_build (both beta): invalid build."
                    invalid_installer_found="yes"
                else
                    writelog "[check_installer_is_valid] Installer: $installer_build >= System: $system_build (both beta): valid build."
                    invalid_installer_found="no"
                fi
            else
                if ! is-at-least "${system_build:0:3}" "${installer_build:0:3}"; then
                    writelog "[check_installer_is_valid] Installer: $installer_build < System: $system_build (beta): invalid build."
                    invalid_installer_found="yes"
                else
                    writelog "[check_installer_is_valid] Installer: $installer_build >= System: $system_build (beta) : valid build."
                    invalid_installer_found="no"
                fi
            fi
        elif ! is-at-least "$system_build" "$installer_build"; then
            writelog "[check_installer_is_valid] Installer: $installer_build < System: $system_build : invalid build."
            invalid_installer_found="yes"
        else
            writelog "[check_installer_is_valid] Installer: $installer_build >= System: $system_build : valid build."
            invalid_installer_found="no"
        fi
    else
        writelog "[check_installer_is_valid] Build of existing installer could not be found, so it is assumed to be invalid."
        invalid_installer_found="yes"
    fi

    working_macos_app="$cached_installer_app"
}

# -----------------------------------------------------------------------------
# Check the validity of an installer pkg.
# packages generated by mist using this script have the name  
# InstallAssistant-VERSION-BUILD.pkg
# Extracting an actual version from the package is slow as the entire package 
# must be unpackaged to read the PackageInfo file, so we just grab it from the 
# filename instead, as mist already did the check.
# -----------------------------------------------------------------------------
check_installer_pkg_is_valid() {
    writelog "[check_installer_pkg_is_valid] Checking validity of $cached_installer_pkg."
    installer_pkg_build=$( basename "$cached_installer_pkg" | sed 's|.pkg||' | cut -d'-' -f3 )

    # compare the local system's build number with that of InstallAssistant.pkg 
    if ! is-at-least "$system_build" "$installer_pkg_build"; then
        writelog "[check_installer_pkg_is_valid] Installer: $installer_pkg_build < System: $system_build : invalid build."
        working_installer_pkg="$cached_installer_pkg"
        invalid_installer_found="yes"
    else
        writelog "[check_installer_pkg_is_valid] Installer: $installer_pkg_build >= System: $system_build : valid build."
        working_installer_pkg="$cached_installer_pkg"
        invalid_installer_found="no"
    fi
}

# -----------------------------------------------------------------------------
# Check that a newer installer is available.
# Used with --update.
# This requires mist, so we first check if this is on the system and download 
# if not.
# We are using mist to list all available installers, with
# options for different catalogs, and whether to include betas or 
# not.
# -----------------------------------------------------------------------------
check_newer_available() {
    # Download mist if not present
    check_for_mist

    # define mist export file location
    mist_export_file="$workdir/mist-list.json"

    # now clear the variables and build the download command
    mist_args=()
    mist_args+=("list")
    mist_args+=("installer")
    mist_args+=("--export")
    mist_args+=("$mist_export_file")
    
    # set the search restriction based on --os, --version or --sameos
    if [[ $prechosen_version ]]; then
        writelog "[check_newer_available] Checking that selected version '$prechosen_version' is available"
        mist_args+=("$prechosen_version")
    elif [[ $prechosen_os ]]; then
        # to avoid a bug where mist-cli does a glob search for the major version, convert it to the name (this is resolved in mist-cli 2.0 but will leave here for now to avoid problems with older installations)
        prechosen_os_name=$(convert_os_to_name "$prechosen_os")
        writelog "[check_newer_available] Restricting to selected OS '$prechosen_os'"
        mist_args+=("$prechosen_os_name")
    fi

    if [[ "$skip_validation" != "yes" ]]; then
        mist_args+=("--compatible")
    fi
    mist_args+=("--latest")

    # set alternative catalog if selected
    if [[ $catalogurl ]]; then
        writelog "[check_newer_available] Non-standard catalog URL selected"
        mist_args+=("--catalog-url")
        mist_args+=("$catalogurl")
    elif [[ $catalog ]]; then
        darwin_version=$(get_darwin_from_os_version "$catalog")
        get_catalog
        writelog "[check_newer_available] Non-default catalog selected (darwin version $darwin_version)"
        mist_args+=("--catalog-url")
        mist_args+=("${catalogs[$darwin_version]}")
    fi

    # include betas if selected
    if [[ $beta == "yes" ]]; then
        writelog "[check_newer_available] Beta versions included"
        mist_args+=("--include-betas")
    fi

    # run in no-ansi mode which is less pretty but better for our logs
    mist_args+=("--no-ansi")

    # run mist with --list and then interrogate the plist
    if "$mist_bin" "${mist_args[@]}" ; then
        newer_build_found="no"
        if [[ -f "$mist_export_file" ]]; then
            available_build=$( ljt 0.build "$mist_export_file" 2>/dev/null )
            if [[ "$available_build" ]]; then
                if [[ $installer_pkg_build ]]; then
                    echo "Comparing latest build found ($available_build) with cached pkg installer build ($installer_pkg_build)"
                else
                    echo "Comparing latest build found ($available_build) with cached installer build ($installer_build)"
                fi
                if ! is-at-least "$available_build" "$installer_build"; then
                    newer_build_found="yes"
                fi
            fi
        else
            writelog "[check_newer_available] ERROR reading output from mist, cannot continue"
            exit 1
        fi
        if [[ "$newer_build_found" == "no" ]]; then 
            writelog "[check_newer_available] No newer builds found"
        fi
    else
        writelog "[check_newer_available] ERROR running mist, cannot continue"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Check that the password entered matches the actual password.
# The password is required on Apple Silicon Mac (Thanks to Dan Snelson).
# -----------------------------------------------------------------------------
check_password() {
    user="$1"
    password="$2"
    password_matches=$( /usr/bin/dscl /Search -authonly "$user" "$password" )

    if [[ -z "$password_matches" ]]; then
        writelog "[check_password] Success: the password entered is the correct login password for $user."
        password_check="pass"
    else
        writelog "[check_password] ERROR: The password entered is NOT the login password for $user."
        password_check="fail"
        /usr/bin/afplay "/System/Library/Sounds/Basso.aiff"
    fi
}

# -----------------------------------------------------------------------------
# Check if device is on battery or AC power.
# If not, and our power_wait_timer is above 1, allow user to connect to power 
# for the specified time period.
# Acknowledgements: https://github.com/kc9wwh/macOSUpgrade/blob/master/macOSUpgrade.sh
# -----------------------------------------------------------------------------
check_power_status() {
    # default power_wait_timer to 60 seconds
    if [[ ! $power_wait_timer ]]; then 
        power_wait_timer=60
    fi

    if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
        writelog "[check_power_status] OK - AC power detected"
    elif [[ $silent ]]; then
        writelog "[check_power_status] ERROR - No AC power detected, cannot continue."
        echo
        exit 1
    else
        if [[ $min_battery_check ]]; then
            # set a sensible absolute minimum battery percentage if using min battery check
            if ((min_battery_check < 15)); then
                min_battery_check=15
            fi
            writelog "[check_power_status] Minimum battery percentage is set to $min_battery_check"
            # check current internal battery percentage
            battery_percentage=$(/usr/bin/pmset -g batt | /usr/bin/grep InternalBattery-0 | /usr/bin/awk '{print $3}' | /usr/bin/sed 's|%;||' 2>/dev/null)
            # check that the battery has a higher percentage remaining than the minimum set
            if ((battery_percentage > min_battery_check)); then
                writelog "[check_power_status] OK - battery power is at $battery_percentage"
                return
            else
                writelog "[check_power_status] WARNING - battery power is at $battery_percentage"
            fi
        fi
        writelog "[check_power_status] WARNING - No AC power detected"
        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        # original icon: ${dialog_confirmation_icon}
        dialog_args+=(
            "--title"
            "${(P)dialog_power_title}"
            "--icon"
            "${dialog_confirmation_icon}"
            "--overlayicon"
            "SF=bolt.slash.fill,colour=red"
            "--iconsize"
            "${dialog_icon_size}"
            "--message"
            "${(P)dialog_power_desc}"
            "--timer"
            "${power_wait_timer}"
        )
        # run the dialog command (stderr to dev/null to prevent Xfont errors)
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null & sleep 0.1

        # now count down while checking for power
        while [[ "$power_wait_timer" -gt 0 ]]; do
            if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
                writelog "[check_power_status] OK - AC power detected"
                # quit dialog
                writelog "[check_power_status] Sending quit message to dialog log ($dialog_log)"
                echo "quit:" >> "$dialog_log"
                return
            fi
            sleep 1
            ((power_wait_timer--))
        done

        # quit dialog
        writelog "[check_power_status] Sending quit message to dialog log ($dialog_log)"
        echo "quit:" >> "$dialog_log"

        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        dialog_args+=(
            "--title"
            "${(P)dialog_power_title}"
            "--icon"
            "${dialog_confirmation_icon}"
            "--iconsize"
            "${dialog_icon_size}"
            "--overlayicon"
            "SF=powerplug.fill,colour=red"
            "--message"
            "${(P)dialog_nopower_desc}"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null

        writelog "[check_power_status] ERROR - No AC power detected after waiting for ${power_wait_timer}s, cannot continue."
        echo
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Confirmation dialogue. 
# Called when --confirm option is used.
# Not used in --silent mode.
# -----------------------------------------------------------------------------
confirm() {
    # options
    if [[ "$erase" == "yes" ]]; then
        local dialog_title="${(P)dialog_erase_title}"
        local dialog_message="${(P)dialog_erase_confirmation_desc}"
    else
        local dialog_title="${(P)dialog_reinstall_title}"
        local dialog_message="${(P)dialog_reinstall_confirmation_desc}"
    fi

    # set the dialog command arguments
    get_default_dialog_args "utility"
    dialog_args=("${default_dialog_args[@]}")
    dialog_args+=(
        "--title"
        "$dialog_title"
        "--icon"
        "${dialog_confirmation_icon}"
        "--iconsize"
        "${dialog_icon_size}"
        "--overlayicon"
        "SF=person.fill.checkmark,colour=red"
        "--message"
        "$dialog_message"
        "--button1text"
        "${(P)dialog_confirmation_button}"
        "--button2text"
        "${(P)dialog_cancel_button}"
    )
    # run the dialog command
    "$dialog_bin" "${dialog_args[@]}" 2>/dev/null
    confirmation=$?

    if [[ "$confirmation" == "2" ]]; then
        writelog "[$script_name] User DECLINED erase-install or reinstall"
        exit 0
    elif [[ "$confirmation" == "0" ]]; then
        writelog "[$script_name] User CONFIRMED erase-install or reinstall"
    else
        writelog "[$script_name] User FAILED to confirm erase-install or reinstall"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# convert OS major version to name
# -----------------------------------------------------------------------------
convert_os_to_name () {
    local os_name
    case "$1" in
        "11") os_name="Big Sur"
            ;;
        "12") os_name="Monterey"
            ;;
        "13") os_name="Ventura"
            ;;
        "14") os_name="Sonoma"
            ;;
        "15") os_name="Sequoia"
            ;;
        *) os_name="$1"
            ;;
    esac
    echo "$os_name"
}

# -----------------------------------------------------------------------------
# convert OS major version to name
# -----------------------------------------------------------------------------
convert_name_to_os () {
    local os_major_version
    case "$1" in
        "Big Sur") os_major_version="11"
            ;;
        "Monterey") os_major_version="12"
            ;;
        "Ventura") os_major_version="13"
            ;;
        "Sonoma") os_major_version="14"
            ;;
        "Sequoia") os_major_version="15"
            ;;
        *) os_major_version="$1"
            ;;
    esac
    echo "$os_major_version"
}

# -----------------------------------------------------------------------------
# Create a LaunchDaemon that runs startosinstall.
# -----------------------------------------------------------------------------
create_launchdaemon_to_run_startosinstall () {
    local install_arg

    # Name of LaunchDaemon
    # set label and file name for LaunchDaemon
    plist_label="$pkg_label.startosinstall"
    launch_daemon="/Library/LaunchDaemons/$plist_label.plist"

    # Create the plist
    if [[ -f "$launch_daemon" ]]; then
        rm "$launch_daemon" 
    fi

    /usr/libexec/PlistBuddy -c "Add :Label string '$plist_label'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :RunAtLoad bool YES" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :LaunchOnlyOnce bool YES" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :StandardInPath string '$pipe_input'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :StandardOutPath string '$pipe_output'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :StandardErrorPath string '$pipe_output'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "$launch_daemon"

    i=0
    for install_arg in "${combined_args[@]}"; do
        /usr/libexec/PlistBuddy -c "Add :ProgramArguments:$i string '$install_arg'" "$launch_daemon"
        (( i++ ))
    done
}

# -----------------------------------------------------------------------------
# Create a LaunchDaemon that removes the working directory after a reboot.
# This is used with the --cleanup-after-use option.
# -----------------------------------------------------------------------------
create_launchdaemon_to_remove_workdir () {
    # Name of LaunchDaemon
    plist_label="$pkg_label.remove"
    launch_daemon="/Library/LaunchDaemons/$plist_label.plist"

    # Create the plist
    /usr/libexec/PlistBuddy -c "Add :Label string '$plist_label'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :RunAtLoad bool YES" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :LaunchOnlyOnce bool YES" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments array" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:0 string '/bin/rm'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:1 string '-Rf'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:2 string '$workdir'" "$launch_daemon"
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments:3 string '$launch_daemon'" "$launch_daemon"

    /usr/sbin/chown root:wheel "$launch_daemon"
    /bin/chmod 644 "$launch_daemon"
}

# -----------------------------------------------------------------------------
# Create a pipe
# -----------------------------------------------------------------------------
create_pipe() {
    local pipe_name=${1}
    local pipe_file
    pipe_file=$( /usr/bin/mktemp -u -t "$pipe_name" || exit 12 )
    /usr/bin/mkfifo -m go-rw "$pipe_file" || exit 13
    echo "$pipe_file"
    return 0
}

# -----------------------------------------------------------------------------
# Show progress information in DEPNotify while the installer is being 
# downloaded or prepared, or during reboot-delay, thanks to @andredb90.
# -----------------------------------------------------------------------------
dialog_progress() {
    last_progress_value=0
    current_progress_value=0
    # initialise progress messages
    writelog "Sending to dialog: progresstext:"
    echo "progresstext: " >> "$dialog_log"
    echo  "progress: 0" >> "$dialog_log"

    if [[ "$1" == "startosinstall" ]]; then
        # Wait for the preparing process to start and set the progress bar to 100 steps
        until grep -q "Preparing to run macOS Installer..." "$LOG_FILE" ; do
            sleep 0.1
        done
        writelog "Sending to dialog: progresstext: Preparing to run macOS Installer..."
        echo "progresstext: Preparing to run macOS Installer..." >> "$dialog_log"
        
        until grep -q "Preparing: \d" "$LOG_FILE" ; do
            sleep 2
        done
        echo "progress: 0" >> "$dialog_log"

        # Until at least 100% is reached, calculate the preparing progress and move the bar accordingly
        until [[ $current_progress_value -ge 100 ]]; do
            until [[ $current_progress_value -gt $last_progress_value ]]; do
                log_value=$(tail -1 "$LOG_FILE" | awk 'END{print substr($NF, 1, length($NF)-3)}')
                # check we got a number
                if [ "$log_value" -eq "$log_value" ] 2>/dev/null; then
                    current_progress_value="$log_value"
                fi
                sleep 1
            done
            echo "progresstext: Preparing macOS Installer ($current_progress_value%)" >> "$dialog_log"
            echo "progress: $current_progress_value" >> "$dialog_log"
            last_progress_value=$current_progress_value
        done

    elif [[ "$1" == "mist" ]]; then
        # if mist runs in quiet mode we cannot display download progress
        if [[ "$quiet" == "yes" ]]; then
            echo "progresstext: Downloading macOS installer..." >> "$dialog_log"
        else
            # Wait for a search message to appear
            until grep -q "SEARCH" "$LOG_FILE" ; do
                sleep 1
            done
            writelog "Sending to dialog: progresstext: Searching for a valid macOS installer..."
            echo "progresstext: Searching for a valid macOS installer..." >> "$dialog_log"

            # Wait for a Found message to appear
            until grep -q "Found \[" "$LOG_FILE" ; do
                sleep 1
            done
            dialog_found_installer=$(/usr/bin/grep "Found \[" "$LOG_FILE" | sed 's/.*Found \[.*\] //' | sed 's/ \[.*\]//')
            writelog "Sending to dialog: progresstext: Found $dialog_found_installer"
            echo "progresstext: Found $dialog_found_installer" >> "$dialog_log"

            # Wait for the download to start and set the progress bar to 100 steps
            until grep -q "DOWNLOAD" "$LOG_FILE" ; do
                sleep 2
            done
            writelog "Sending to dialog: progresstext: Downloading $dialog_found_installer"
            echo "progresstext: Downloading $dialog_found_installer" >> "$dialog_log"
            echo  "progress: 0" >> "$dialog_log"
            # Wait for the InstallAssistant package to start downloading
            until grep -q "InstallAssistant.pkg" "$LOG_FILE" ; do
                sleep 2
            done
            echo  "progress: 0" >> "$dialog_log"
            sleep 2
            until [[ $current_progress_value -gt 100 ]]; do
                until [[ $current_progress_value -gt $last_progress_value ]]; do
                    progress_from_mist=$(grep "InstallAssistant" "$LOG_FILE" | tail -1 | cut -d'(' -f2 | cut -d')' -f1)
                    current_progress_value=$(cut -d. -f1 <<< "$progress_from_mist" | sed 's|^0||')
                    sleep 2
                done
                echo "progresstext: Downloading $dialog_found_installer ($current_progress_value%)" >> "$dialog_log"
                echo "progress: $current_progress_value" >> "$dialog_log"
                last_progress_value=$current_progress_value
            done
            # if the percentage reaches or goes over 100, show that we are finishing up
            writelog "Sending to dialog: progress: complete"
            echo "progresstext: Preparing downloaded macOS installer" >> "$dialog_log"
            writelog "Sending to dialog: progresstext: Preparing downloaded macOS installer"
            echo "progress: complete" >> "$dialog_log"
        fi

    elif [[ "$1" == "fetch-full-installer" ]]; then
        writelog "Sending to dialog: progresstext: Searching for a valid macOS installer..."
        echo "progresstext: Searching for a valid macOS installer..." >> "$dialog_log"
        # Wait for the download to start and set the progress bar to 100 steps
        until grep -q "Installing:" "$LOG_FILE" ; do
            sleep 2
        done
        writelog "Sending to dialog: progresstext: Downloading $dialog_found_installer"
        echo "progresstext: Downloading $dialog_found_installer" >> "$dialog_log"
        echo "progress: 0" >> "$dialog_log"

        # Until at least 100% is reached, calculate the downloading progress and move the bar accordingly
        until [[ "$current_progress_value" -ge 100 ]]; do
            until [ "$current_progress_value" -gt "$last_progress_value" ]; do
                current_progress_value=$(tail -1 "$LOG_FILE" | awk 'END{print substr($NF, 1, length($NF)-3)}')
                sleep 2
            done
            echo "progresstext: Downloading $dialog_found_installer ($current_progress_value%)" >> "$dialog_log"
            echo "progress: $current_progress_value" >> "$dialog_log"
            last_progress_value=$current_progress_value
        done
        # if the percentage reaches or goes over 100, show that we are finishing up
        writelog "Sending to dialog: progresstext: Preparing downloaded macOS installer"
        echo "progresstext: Preparing downloaded macOS installer" >> "$dialog_log"
        writelog "Sending to dialog: progress: complete"
        echo "progress: complete" >> "$dialog_log"

    elif [[ "$1" == "reboot-delay" ]]; then
        # Countdown seconds to reboot (a bit shorter than rebootdelay)
        countdown=$((rebootdelay-2))
        echo "progress: $countdown" >> "$dialog_log"
        until [ "$countdown" -eq 0 ]; do
            sleep 1
            current_progress_value=$countdown
            echo "progresstext: Computer will be restarted in $countdown seconds" >> "$dialog_log"
            echo "progress: $countdown" >> "$dialog_log"
            ((countdown--))
        done
    fi
}

# -----------------------------------------------------------------------------
# Search for an existing downloaded installer.
# This checks first for an Install macOS X.app in the /Applications folder, 
# and then for an InstallAssistant.pkg in the working directory.
# Note that multiple installers left around on the device can cause unexpected
# results.  
# -----------------------------------------------------------------------------
find_existing_installer() {
    # First let's see if this script has been run before and left an installer
    cached_installer_app=$( find "$installer_directory" -maxdepth 1 -name "Install macOS*.app" -type d -print -quit 2>/dev/null )
    cached_installer_app_in_workdir=$( find "$workdir" -maxdepth 1 -name "Install macOS*.app" -type d -print -quit 2>/dev/null )
    cached_installer_pkg=$( find "$workdir" -maxdepth 1 -name "InstallAssistant*.pkg" -type f -print -quit 2>/dev/null )

    if [[ -d "$cached_installer_app" ]]; then
        writelog "[find_existing_installer] Installer found at $cached_installer_app."
        app_is_in_applications_folder="yes"
        check_installer_is_valid
    elif [[ -d "$cached_installer_app_in_workdir" ]]; then
        cached_installer_app="$cached_installer_app_in_workdir"
        writelog "[find_existing_installer] Installer found at $cached_installer_app_in_workdir."
        check_installer_is_valid
    elif [[ -f "$cached_installer_pkg" ]]; then
        writelog "[find_existing_installer] InstallAssistant package found at $cached_installer_pkg."
        check_installer_pkg_is_valid
    else
        writelog "[find_existing_installer] No valid installer found."
        if [[ $clear_cache == "yes" ]]; then
            exit
        fi
    fi
}

# -----------------------------------------------------------------------------
# Look for packages to install during the startosinstall run.
# The default location is: $workdir/extras
# This location can be overridden with the --extras option.
# -----------------------------------------------------------------------------
find_extra_packages() {
    # set install_package_list to blank.
    if [[ -d "$extras_directory" ]]; then
        install_package_list=()
        for file in "$extras_directory"/*.pkg; do
            if [[ $file != *"/*.pkg" ]]; then
                writelog "[find_extra_installers] Additional package to install: $file"
                install_package_list+=("--installpackage")
                install_package_list+=("$file")
            fi
        done
    fi
}

# -----------------------------------------------------------------------------
# Things to carry out when the script exits
# -----------------------------------------------------------------------------
# shellcheck disable=SC2317
finish() {
    local exit_code=${1:-$?}
    # if we promoted the user then we should demote it again
    if [[ $promoted_user ]]; then
        /usr/sbin/dseditgroup -o edit -d "$promoted_user" admin
        writelog "[finish] User $promoted_user was demoted back to standard user"
    fi

    # remove pipe files
    [[ -e "${pipe_input}" ]] && /bin/rm -f "${pipe_input}"
    [[ -e "${pipe_output}" ]] && /bin/rm -f "${pipe_output}"

    # kill caffeinate
    kill_process "caffeinate"

    # kill any dialogs if startosinstall quits without rebooting the machine (exit code > 0)
    if [[ $test_run == "yes" || $exit_code -gt 0 ]]; then
        writelog "[finish] sending quit message to dialog ($dialog_log)"
        echo "quit:" >> "$dialog_log"
        # delete dialog logfile
        sleep 0.5
        # /bin/rm -f "$dialog_log"
    fi

    # set final exit code and quit, but do not call finish() again
    writelog "[finish] Script exit code: $exit_code"
    (exit "$exit_code")
}

# -----------------------------------------------------------------------------
# Determine the Darwin number from the macOS version.
# -----------------------------------------------------------------------------
get_darwin_from_os_version() {
    # convert a macOS major version to a darwin version
    os_major="$1"
    os_major_check=$(cut -d. -f1 <<< "$os_major")
    if [[ $os_major_check -eq 10 ]]; then
        darwin_version=$(cut -d. -f2 <<< "$os_major")
        darwin_version=$((darwin_version+4))
    else
        darwin_version=$((os_major_check+9))
    fi
    echo "$darwin_version"
}

# -----------------------------------------------------------------------------
# Get a password from keychain
# This is NOT a recommended method for production workflows for obvious security reasons.
# Use at your own risk!!
# -----------------------------------------------------------------------------
read_from_keychain() {
    # expects entries from the command line for keychain name, password, service name for the user and service name for the password
    writelog "[read_from_keychain] Attempting to unlock keychain..."
    if security unlock-keychain -p "$kc_pass" "$kc"; then
        writelog "[read_from_keychain] Unlocked keychain..."
        account_shortname=$(security find-generic-password -s "$kc_service" -g "$kc" 2>&1 | grep "acct" | cut -d \" -f4)
        [[ $account_shortname ]] && writelog "[read_from_keychain] Obtained user $account_shortname..."
        account_password=$(security find-generic-password -s "$kc_service" -g "$kc" 2>&1 | grep "password" | cut -d \" -f2)
        [[ $account_password ]] && writelog "[read_from_keychain] Obtained password..."
    else
        writelog "[read_from_keychain] Could not unlock keychain. Continuing..."
    fi
}

# -----------------------------------------------------------------------------
# Set catalog URLs.
# This provides a shortcut way of obtaining different catalog URLs for different
# systems.
# -----------------------------------------------------------------------------
get_catalog() {
    catalogs[19]="https://swscan.apple.com/content/catalogs/others/index-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
    catalogs[20]="https://swscan.apple.com/content/catalogs/others/index-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
    catalogs[21]="https://swscan.apple.com/content/catalogs/others/index-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
    catalogs[22]="https://swscan.apple.com/content/catalogs/others/index-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
    catalogs[23]="https://swscan.apple.com/content/catalogs/others/index-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
    catalogs[24]="https://swscan.apple.com/content/catalogs/others/index-15-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
}

# -----------------------------------------------------------------------------
# Default dialog arguments
# -----------------------------------------------------------------------------
get_default_dialog_args() {
    # set the dialog command arguments
    # $1 - window type
    default_dialog_args=(
        "--commandfile"
        "$dialog_log"
        "--ontop"
        "--json"
        "--ignorednd"
        "--position"
        "centre"
        "--quitkey"
        "c"
    )
    if [[ "$1" == "fullscreen" ]]; then
        writelog "[get_default_dialog_args] Invoking fullscreen dialog"
        default_dialog_args+=(
            "--blurscreen"
            "--width"
            "50%"
            "--height"
            "50%"
            "--button1disabled"
            "--centreicon"
            "--titlefont"
            "size=32"
            "--messagefont"
            "size=24"
            "--alignment"
            "centre"
        )
    elif [[ "$1" == "utility" ]]; then
        writelog "[get_default_dialog_args] Invoking utility dialog"
        default_dialog_args+=(
            "--moveable"
            "--width"
            "600"
            "--height"
            "300"
            "--titlefont"
            "size=20"
            "--messagefont"
            "size=14"
            "--alignment"
            "left"
        )
    fi
}

# -----------------------------------------------------------------------------
# Get the system's device ID (Apple Silicon) or board ID (Intel)
# -----------------------------------------------------------------------------
get_device_id() {
    device_info=$(/usr/sbin/ioreg -c IOPlatformExpertDevice -d 2)
    board_id=$(grep board-id <<< "$device_info" | awk -F '<"|">' '{ print $2 }')
    device_id=$(grep target-sub-type <<< "$device_info" | awk -F '<"|">' '{ print $2 }')
}

# -----------------------------------------------------------------------------
# Run mist list to get some required output for automation
# This requires mist, so we first check if it is on the system and download them if not.
# -----------------------------------------------------------------------------
get_mist_list() {
    # Download mist if not present
    check_for_mist

    # define mist export file location
    mist_export_file="$workdir/mist-list.json"

    mist_args=()
    mist_args+=("list")
    mist_args+=("installer")
    if [[ "$skip_validation" != "yes" ]]; then
        mist_args+=("--compatible")
    fi

    mist_args+=("--export")
    mist_args+=("$mist_export_file")

    # set alternative catalog if selected
    if [[ $catalogurl ]]; then
        writelog "[get_mist_list] Non-standard catalog URL selected"
        mist_args+=("--catalog-url")
        mist_args+=("$catalogurl")
    elif [[ $catalog ]]; then
        darwin_version=$(get_darwin_from_os_version "$catalog")
        get_catalog
        writelog "[get_mist_list] Non-default catalog selected (darwin version $darwin_version)"
        mist_args+=("--catalog-url")
        mist_args+=("${catalogs[$darwin_version]}")
    fi

    # include betas if selected
    if [[ $beta == "yes" ]]; then
        writelog "[get_mist_list] Beta versions included"
        mist_args+=("--include-betas")
    fi

    # run in no-ansi mode which is less pretty but better for our logs
    mist_args+=("--no-ansi")

    # run the command
    if ! "$mist_bin" "${mist_args[@]}" ; then
        writelog "[get_mist_list] An error occurred running mist. Cannot continue."
        echo
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Get the user account name and password.
# Apple Silicon devices require a username and password to run startosinstall.
# The current user is determined.
# The "real name" is also allowed if the user inputs that instead of their
# account name.
# The user is checked to see if it is a VolumeOwner, as this is required.
# The entered password is checked to see if it is correct.
# The user is given a number of attempts to enter their password (default=5).
# If --max-password-attempts is set to "infinite" then there is no limit and 
# no cancel button.
# Finally, with the --erase option, the user is promoted to admin if required.
# -----------------------------------------------------------------------------
get_user_details() {
    # get password and check that the password is correct
    password_attempts=1
    password_check="fail"
    while [[ "$password_check" != "pass" ]] ; do
        writelog "[get_user_details] ask for user credentials (attempt $password_attempts/$max_password_attempts)"
        # on the first attempt only, attempt to get credentials from a keychain if all values supplied from the command line - 
        # recommended for testing only!! 
        # otherwise, ask via dialog
        if [[ $password_attempts = 1 && $kc && $kc_pass ]]; then
            read_from_keychain
        elif [[ $password_attempts = 1 && $credentials && $very_insecure_mode == "yes" ]]; then
            credentials_decoded=$(base64 -d <<< "$credentials")
            if [[ $(awk -F: '{print NF-1}' <<< "$credentials_decoded") -eq 1 ]]; then
                account_shortname=$(awk -F: '{print $1}' <<< "$credentials_decoded")
                account_password=$(awk -F: '{print $NF}' <<< "$credentials_decoded")
            else
                writelog "[get_user_details] ERROR: Supplied credentials are in the incorrect form, so exiting..."
                exit 1
            fi
        elif ! pgrep -q Finder ; then
            writelog "[get_user_details] ERROR! The startosinstall binary requires a user to be logged in."
            echo
            # kill caffeinate
            kill_process "caffeinate"
            exit 1
        elif [[ ! $silent ]]; then
            ask_for_credentials
            if [[ $? -eq 2 ]]; then
                writelog "[get_user_details] user cancelled dialog so exiting..."
                exit 0
            fi

            # get account name (short name) and password
            account_shortname=$(ljt '/Username' < "$dialog_output")
            account_password=$(ljt '/Password' < "$dialog_output")
        fi

        if [[ ! "$account_shortname" ]]; then
            if [[ "$current_user" ]]; then
                account_shortname="$current_user"
            else
                writelog "[get_user_details] Current user was not determined."
                if [[ ($max_password_attempts != "infinite" && $password_attempts -ge $max_password_attempts) || $silent ]]; then
                    user_is_invalid
                    echo
                    exit 1
                fi
                ((password_attempts++))
                continue
            fi
        fi

        # check that this user exists
        if ! /usr/sbin/dseditgroup -o checkmember -m "$account_shortname" everyone ; then
            writelog "[get_user_details] $account_shortname account cannot be found!"
            if [[ ($max_password_attempts != "infinite" && $password_attempts -ge $max_password_attempts) || $silent ]]; then
                password_is_invalid
                echo
                exit 1
            fi
            ((password_attempts++))
            continue
        fi

        # check that the user is a Volume Owner
        user_is_volume_owner=0
        users=$(/usr/sbin/diskutil apfs listUsers /)
        while read -r line ; do
            user=$(/usr/bin/cut -d, -f1 <<< "$line")
            guid=$(/usr/bin/cut -d, -f2 <<< "$line")
            # passwords are case sensitive, account names are not
            if [[ $(/usr/bin/grep -A2 "$guid" <<< "$users" | /usr/bin/tail -n1 | /usr/bin/awk '{print $NF}') == "Yes" ]]; then
                enabled_users+="$user "
                # The entered username might not match the output of fdesetup, so we compare
                # all RecordNames for the canonical name given by fdesetup against the entered
                # username, and then use the canonical version. The entered username might
                # even be the RealName, and we still would end up here.
                # Example:
                # RecordNames for user are "John.Doe@pretendco.com" and "John.Doe", fdesetup
                # says "John.Doe@pretendco.com", and account_shortname is "john.doe" or "Doe, John"
                user_record_names_xml=$(/usr/bin/dscl -plist /Search -read "Users/$user" RecordName dsAttrTypeStandard:RecordName)
                # loop through recordName array until error (we do not know the size of the array)
                record_name_index=0
                while true; do
                    if ! user_record_name=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RecordName:${record_name_index}" /dev/stdin 2>/dev/null <<< "$user_record_names_xml") ; then
                        break
                    fi
                    if [[ "${account_shortname:u}" == "${user_record_name:u}" ]]; then
                        account_shortname="$user"
                        writelog "[get_user_details] $account_shortname is a Volume Owner"
                        user_is_volume_owner=1
                        break
                    fi
                    ((record_name_index++))
                done
                # if needed, compare the RealName (which might contain spaces)
                if [[ $user_is_volume_owner -eq 0 ]]; then
                    user_real_name=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RealName:0" /dev/stdin <<< "$(/usr/bin/dscl -plist /Search -read "Users/$user" RealName)")
                    if [[ "${account_shortname:u}" == "${user_real_name:u}" ]]; then
                        account_shortname="$user"
                        writelog "[get_user_details] $account_shortname is a Volume Owner"
                        user_is_volume_owner=1
                    fi
                fi
            fi
        done <<< "$(/usr/bin/fdesetup list)"

        if [[ $enabled_users != "" && $user_is_volume_owner -eq 0 ]]; then
            writelog "[get_user_details] $account_shortname is not a Volume Owner"
            user_not_volume_owner
            if [[ ($max_password_attempts != "infinite" && $password_attempts -ge $max_password_attempts) || $silent ]]; then
                password_is_invalid
                exit 1
            fi
            ((password_attempts++))
            continue
        fi

        # check that the password is correct
        check_password "$account_shortname" "$account_password"

        if [[ "$password_check" != "pass" && (($max_password_attempts != "infinite" && $password_attempts -ge $max_password_attempts) || $silent)  ]]; then
            password_is_invalid
            exit 1
        fi
        ((password_attempts++))
    done

    # if we are performing eraseinstall the user needs to be an admin so let's promote the user
    if [[ $erase == "yes" ]]; then
        if ! /usr/sbin/dseditgroup -o checkmember -m "$account_shortname" admin ; then
            if /usr/sbin/dseditgroup -o edit -a "$account_shortname" admin ; then
                writelog "[get_user_details] $account_shortname account has been promoted to admin so that eraseinstall can proceed"
                promoted_user="$account_shortname"
            else
                writelog "[get_user_details] $account_shortname account could not be promoted to admin so eraseinstall cannot proceed"
                user_is_invalid
                exit 1
            fi
        fi
    fi
}

# -----------------------------------------------------------------------------
# Kill a specified process
# -----------------------------------------------------------------------------
kill_process() {
    process="$1"
    echo
    if process_pid=$(/usr/bin/pgrep -a "$process" 2>/dev/null) ; then
        writelog "[$script_name] terminating the process '$process' process"
        kill "$process_pid" 2> /dev/null
        if /usr/bin/pgrep -a "$process" >/dev/null ; then
            writelog "[$script_name] ERROR: '$process' could not be killed"
        fi
        echo
    fi
}

# -----------------------------------------------------------------------------
# We launch startosinstall via a LaunchDaemon to allow this script to exit
# before the computer restarts
# -----------------------------------------------------------------------------
launch_startosinstall() {
    # Prepare pipes for communication with startosinstall
    pipe_input=$( create_pipe "$script_name.in" )
    exec 3<> "$pipe_input"
    pipe_output=$( create_pipe "$script_name.out" )
    exec 4<> "$pipe_output"
    /bin/cat <&4 &
    pipePID=$!

    # set label and file name for LaunchDaemon
    plist_label="$pkg_label.startosinstall"
    launch_daemon="/Library/LaunchDaemons/$plist_label.plist"

    # reset the existing launchdaemon if present
    if /bin/launchctl list "$plist_label" >/dev/null 2>&1; then
        /bin/launchctl bootout system "$launch_daemon"
        /bin/rm "$launch_daemon"
    fi

    # prepare command parameters
    combined_args=()
    if [[ $test_run == "yes" ]]; then
        combined_args+=("/bin/zsh")
        combined_args+=("-c")
        combined_args+=("echo \"Simulating startosinstall.\"; sleep 5; echo \"Sending USR1 to PID $$.\"; kill -s USR1 $$")

        test_args=()
        test_args+=("$working_macos_app/Contents/Resources/startosinstall")
        test_args+=("--pidtosignal")
        test_args+=("$$")
        test_args+=("--agreetolicense")
        test_args+=("--nointeraction")
        if [[ "${#install_args[@]}" -ge 1 ]]; then
            test_args+=("${install_args[@]}")
        fi
        if [[ "${#install_package_list[@]}" -ge 1 ]]; then
            test_args+=("${install_package_list[@]}")
        fi

        writelog "[launch_startosinstall] Run without '--test-run' to run this command:"
        writelog "[launch_startosinstall] $(printf "%q " "${test_args[@]}")"
    else
        combined_args+=("$working_macos_app/Contents/Resources/startosinstall")
        combined_args+=("--pidtosignal")
        combined_args+=("$$")
        combined_args+=("--agreetolicense")
        combined_args+=("--nointeraction")
        if [[ "${#install_args[@]}" -ge 1 ]]; then
            combined_args+=("${install_args[@]}")
        fi
        if [[ "${#install_package_list[@]}" -ge 1 ]]; then
            combined_args+=("${install_package_list[@]}")
        fi
    
        writelog "[launch_startosinstall] This is the startosinstall command that will be used:"
        writelog "[launch_startosinstall] $(printf "%q " "${combined_args[@]}")"
        writelog "[launch_startosinstall] Launching startosinstall..."
fi

    # write the launchdaemon
    create_launchdaemon_to_run_startosinstall

    # Start LaunchDaemon
    /usr/sbin/chown root:wheel "$launch_daemon"
    /bin/chmod 644 "$launch_daemon"
    /bin/launchctl bootstrap system "$launch_daemon"
    /bin/rm -f "$launch_daemon"
    return 0
}

# -----------------------------------------------------------------------------
# ljt v1.0.9
# This is used only to help obtain the correct version of MacAdmins Python.
# -----------------------------------------------------------------------------
: <<-LICENSE_BLOCK
ljt.min - Little JSON Tool (https://github.com/brunerd/ljt) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

ljt() ( #v1.0.9 ljt [query] [file]
    { set +x; } &> /dev/null; read -r -d '' JSCode <<-'EOT'
try{var query=decodeURIComponent(escape(arguments[0]));var file=decodeURIComponent(escape(arguments[1]));if(query===".")query="";else if(query[0]==="."&&query[1]==="[")query="$"+query.slice(1);if(query[0]==="/"||query===""){if(/~[^0-1]/g.test(query+" "))throw new SyntaxError("JSON Pointer allows ~0 and ~1 only: "+query);query=query.split("/").slice(1).map(function(f){return"["+JSON.stringify(f.replace(/~1/g,"/").replace(/~0/g,"~"))+"]"}).join("")}else if(query[0]==="$"||query[0]==="."&&query[1]!=="."||query[0]==="["){if(/[^A-Za-z_$\d\.\[\]'"]/.test(query.split("").reverse().join("").replace(/(["'])(.*?)\1(?!\\)/g,"")))throw new Error("Invalid path: "+query);}else query=query.replace(/\\\./g,"\uDEAD").split(".").map(function(f){return "["+JSON.stringify(f.replace(/\uDEAD/g,"."))+"]"}).join('');if(query[0]==="$")query=query.slice(1);var data=JSON.parse(readFile(file));try{var result=eval("(data)"+query)}catch(e){}}catch(e){printErr(e);quit()}if(result!==undefined)result!==null&&result.constructor===String?print(result):print(JSON.stringify(result,null,2));else printErr("Path not found.")
EOT

    queryArg="${1}"; fileArg="${2}"; jsc=$(find "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/" -name 'jsc'); [ -z "${jsc}" ] && jsc=$(which jsc); [[ -f "${queryArg}" && -z "${fileArg}" ]] && fileArg="${queryArg}" && unset queryArg; if [ -f "${fileArg:=/dev/stdin}" ]; then { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "${fileArg}"; } 1>&3 ; } 2>&1); } 3>&1; else [ -t '0' ] && echo -e "ljt (v1.0.9) - Little JSON Tool (https://github.com/brunerd/ljt)\nUsage: ljt [query] [filepath]\n  [query] is optional and can be JSON Pointer, canonical JSONPath (with or without leading $), or plutil-style keypath\n  [filepath] is optional, input can also be via file redirection, piped input, here doc, or here strings" >/dev/stderr && exit 0; { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "/dev/stdin" <<< "$(cat)"; } 1>&3 ; } 2>&1); } 3>&1; fi; if [ -n "${errOut}" ]; then echo "$errOut" >&2; return 1; fi
)

# -----------------------------------------------------------------------------
# Move the installer to the /Applications folder if not already there.
# This is called with the --move option.
# -----------------------------------------------------------------------------
move_to_applications_folder() {
    if [[ $app_is_in_applications_folder == "yes" ]]; then
        writelog "[move_to_applications_folder] Valid installer already in $installer_directory folder"
    else
        writelog "[move_to_applications_folder] Moving $working_macos_app to $installer_directory folder"
        mv "$working_macos_app" "$installer_directory/"
        working_macos_app=$( find "$installer_directory/Install macOS"*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        writelog "[move_to_applications_folder] Installer moved to $installer_directory folder"
    fi
}

# -----------------------------------------------------------------------------
# Rotate existing log files up to a maximum of 9 log files
# Older files will be overwritten
# -----------------------------------------------------------------------------
log_rotate() {
    # logs probably cannot be rotated when running as root
    if [[ $EUID -ne 0 ]]; then
        writelog "[log_rotate] Not running as root so cannot rotate logs"
        return
    fi

    # writelog "[log_rotate] Start rotating logs in $logdir"
    max_log_keep=9

    # move all logs up one file
    i="$max_log_keep"
    while [[ "$i" -gt 0 ]];do
        current_filename="$LOG_FILE.$((i-1))"
        new_filename="$LOG_FILE.$i"
        if [[ -f "$current_filename" ]];then
            # writelog "[log_rotate] moving $current_filename to $new_filename"
            mv "$current_filename" "$new_filename"
        fi
        ((i--))
    done

    if [[ -f "$LOG_FILE" ]];then
        # writelog "[log_rotate] moving $LOG_FILE to $LOG_FILE.1"
        mv "$LOG_FILE" "$LOG_FILE.1"
    fi

    # now create the new log file
    echo "" > "$LOG_FILE"
    exec > >(tee "${LOG_FILE}") 2>&1

    writelog "[log_rotate] Finished rotating logs in $logdir"
}

# -----------------------------------------------------------------------------
# Overwrite an existing installer.
# This is called with the --overwrite option.
# Note that multiple installers left around on the device can cause unexpected
# results.  
# -----------------------------------------------------------------------------
overwrite_existing_installer() {
    if [[ -f "$working_installer_pkg" ]]; then
        writelog "[$script_name] Deleting existing installer package"
        rm -f "$working_installer_pkg"
    else
        writelog "[overwrite_existing_installer] Overwrite option selected. Deleting existing version."
    fi
    rm -f "$cached_installer_pkg" 
    rm -rf "$cached_installer_app"
    app_is_in_applications_folder=""
    if [[ $clear_cache == "yes" ]]; then
        writelog "[overwrite_existing_installer] Cached installers have been removed. Quitting script as --clear-cache-only option was selected"
        exit
    fi
}

# -----------------------------------------------------------------------------
# Things to do after startosinstall has finished preparing
# -----------------------------------------------------------------------------
# shellcheck disable=SC2317
post_prep_work() {
    # set dialog progress for rebootdelay if set
    if [[ "$rebootdelay" -gt 10 && ! $silent && $fs != "yes" ]]; then
        # quit an existing window
        writelog "[post_prep_work] Sending quit message to dialog log ($dialog_log)"
        echo "quit:" >> "$dialog_log"
        writelog "[post_prep_work] Opening full screen dialog (language=$user_language)"

        window_type="utility"
        iconsize=$dialog_icon_size

        # set the dialog command arguments
        get_default_dialog_args "$window_type"
        dialog_args=("${default_dialog_args[@]}")
        dialog_args+=(
            "--title"
            "${(P)dialog_reinstall_title}"
            "--icon"
            "${dialog_install_icon}"
            "--iconsize"
            "$iconsize"
            "--message"
            "${(P)dialog_rebooting_heading}"
            "--button1disabled"
            "--progress"
            "$rebootdelay"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null & sleep 0.1

        dialog_progress reboot-delay >/dev/null 2>&1 &
    fi

    # run any postinstall commands
    for command in "${postinstall_command[@]}"; do
        if [[ $command ]]; then
            writelog "[post_prep_work] Now running postinstall command: $command"
            eval "$command"
        fi
    done

    if [[ $test_run == "yes" ]]; then
        writelog "[post_prep_work] Simulating reboot delay of ${rebootdelay}s"
        sleep "$rebootdelay"
    else
        # we need to quit so our management system can report back home before being killed by startosinstall
        writelog "[post_prep_work] Reboot delay set to ${rebootdelay}s"
        # then shut everything down
        kill_process "Self Service"
    fi

    # set exit code to 0 which will call finish()
    exit 0
}

# -----------------------------------------------------------------------------
# Run softwareupdate --fetch-full-installer
# Includes some fallbacks, because --list-full-installers might not be 
# available in some versions of Catalina. 
# -----------------------------------------------------------------------------
run_fetch_full_installer() {
    softwareupdate_args=()
    run_list_full_installers
    if [[ -f "$workdir/ffi-list-full-installers.txt" ]]; then
        if [[ $prechosen_version ]]; then
            # check that this version is available in the list
            ffi_available=$(grep -c -E "Version: $prechosen_version," "$workdir/ffi-list-full-installers.txt")
            if [[ $ffi_available -ge 1 ]]; then
                # check that the latest version is compatible with this system
                if ! is-at-least "$system_version" "$prechosen_version"; then 
                    writelog "[run_fetch_full_installer] ERROR: version in catalog $prechosen_version is older than the system version $system_version"
                    echo
                    exit 1
                fi

                # get the chosen version
                writelog "[run_fetch_full_installer] Found version $prechosen_version"
                softwareupdate_args+=("--full-installer-version")
                softwareupdate_args+=("$prechosen_version")
            else
                writelog "[run_fetch_full_installer] WARNING: $prechosen_version not found. Defaulting to latest available version."
            fi
        elif [[ $prechosen_os ]]; then
            # check that this OS is available in the list
            ffi_available=$(grep -c -E "Version: $prechosen_os." "$workdir/ffi-list-full-installers.txt")
            if [[ $ffi_available -ge 1 ]]; then
                # get the latest version within the chosen OS
                if [[ "$beta" == "yes" ]]; then
                    latest_ffi=$(grep -E "Version: $prechosen_os." "$workdir/ffi-list-full-installers.txt" | head -n1 | cut -d, -f2 | sed 's|.*Version: ||')
                else
                    latest_ffi=$(grep -E "Version: $prechosen_os." "$workdir/ffi-list-full-installers.txt" | grep -v beta | head -n1 | cut -d, -f2 | sed 's|.*Version: ||')
                fi

                # check that the latest version is compatible with this system
                if ! is-at-least "$system_version" "$latest_ffi"; then 
                    writelog "[run_fetch_full_installer] ERROR: latest version in catalog $latest_ffi is older than the system version $system_version"
                    echo
                    exit 1
                fi

                writelog "[run_fetch_full_installer] Found version $latest_ffi"
                softwareupdate_args+=("--full-installer-version")
                softwareupdate_args+=("$latest_ffi")
            else
                writelog "[run_fetch_full_installer] ERROR: No available version for macOS $prechosen_os found."
                echo
                exit 1
            fi
        else
            # if no version is selected, we want to obtain the latest. The list obtained from
            # --list-full-installers appears to always be in order of newest to oldest, so we can grab the first one
            latest_ffi=$(grep -E "Version:" "$workdir/ffi-list-full-installers.txt" | head -n1 | cut -d, -f2 | sed 's|.*Version: ||')

            if [[ $latest_ffi ]]; then
                # we need to check if this version is older than the current system and abort if so
                writelog "is-at-least \"$latest_ffi\" \"$system_version\"" # TEMP
                if ! is-at-least "$system_version" "$latest_ffi"; then 
                    writelog "[run_fetch_full_installer] ERROR: latest version in catalog $latest_ffi is older than the system version $system_version"
                    echo
                    exit 1
                fi
                softwareupdate_args+=("--full-installer-version")
                softwareupdate_args+=("$latest_ffi")
            else
                writelog "[run_fetch_full_installer] Could not obtain installer information using softwareupdate. Defaulting to no specific version, which should obtain the latest but is not as reliable."
            fi
        fi
    else
        # if --list-full-installers did not work, then we cannot continue
        writelog "[run_fetch_full_installer] Could not obtain installer information using softwareupdate --list-full-installers. Cannot continue."
        echo
        exit 1
    fi

    # now download the installer
    writelog "[run_fetch_full_installer] Running /usr/sbin/softwareupdate --fetch-full-installer $(printf "%q " "${softwareupdate_args[@]}")"
    if /usr/sbin/softwareupdate --fetch-full-installer "${softwareupdate_args[@]}"; then
        # Identify the installer
        if find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null ; then
            cached_installer_app=$( find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null )
            # if we actually want to use this installer we should check that it's valid
            if [[ $erase == "yes" || $reinstall == "yes" ]]; then
                check_installer_is_valid
                if [[ $invalid_installer_found == "yes" ]]; then
                    writelog "[run_fetch_full_installer] The downloaded app is invalid for this computer. Try with --version or without --fetch-full-installer"
                    exit 1
                fi
            fi
        else
            writelog "[run_fetch_full_installer] No install app found. I guess nothing got downloaded."
            exit 1
        fi
    else
        writelog "[run_fetch_full_installer] softwareupdate --fetch-full-installer failed. Try without --fetch-full-installer option."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Run softwareupdate --list-full-installers and output to a file
# -----------------------------------------------------------------------------
run_list_full_installers() {
    if [[ $beta == "yes" ]]; then
        if /usr/sbin/softwareupdate --list-full-installers | grep -v "Deferred: YES" > "$workdir/ffi-list-full-installers.txt"; then
            if [[ $(grep -c -E "Version:" "$workdir/ffi-list-full-installers.txt") -lt 1 ]]; then
                writelog "[run_list_full_installers] Could not obtain installer information using softwareupdate."
                exit 1
            fi
        fi
    else
        if /usr/sbin/softwareupdate --list-full-installers | grep -v "Deferred: YES" | grep -v "Beta," > "$workdir/ffi-list-full-installers.txt"; then
            if [[ $(grep -c -E "Version:" "$workdir/ffi-list-full-installers.txt") -lt 1 ]]; then
                writelog "[run_list_full_installers] Could not obtain installer information using softwareupdate."
                exit 1
            fi
        fi
    fi
}

# -----------------------------------------------------------------------------
# Run mist with chosen options.
# This requires mist, so we first check if it is on the system and download them if not.
# -----------------------------------------------------------------------------
run_mist() {
    # first, if we didn't already check for updates, run mist list to get some needed information about builds
    get_mist_list

    # define mist export file location
    mist_export_file="$workdir/mist-list.json"

    # now clear the variables and build the download command
    mist_args=()
    mist_args+=("download")
    mist_args+=("installer")

    # restrict to a particular major OS if selected
    if [[ $prechosen_os ]]; then
        # check whether chosen OS is older than the system
        prechosen_os=$(convert_name_to_os "$prechosen_os")

        if ! is-at-least "${system_version/\.*/}" "$prechosen_os"; then
            writelog "[run_mist] ERROR: cannot select an older OS ($prechosen_os) than the system (${system_version/\.*/}), cannot continue."
            echo
            exit 1
        else
            writelog "[run_mist] Selected OS ($prechosen_os) is the same as or newer than the system (${system_version/\.*/}), proceeding..."
        fi
        # to avoid a bug where mist-cli does a glob search for the major version, convert it to the name (this is resolved in mist-cli 2.0 but will leave here for now to avoid problems with older installations)
        prechosen_os_name=$(convert_os_to_name "$prechosen_os")
        writelog "[run_mist] Restricting to selected OS '$prechosen_os'"
        mist_args+=("$prechosen_os_name")

    # restrict to a particular version if selected
    elif [[ $prechosen_version ]]; then
        if ! is-at-least "$system_version" "$prechosen_version"; then 
            writelog "[run_mist] ERROR: cannot select an older version ($prechosen_version) than the system($system_version)"
            echo
            exit 1
        else
            writelog "[run_mist] Selected version ($prechosen_version) is the same as or newer than the system ($system_version), proceeding..."
        fi
        writelog "[run_mist] Checking that selected version $prechosen_version is available"
        mist_args+=("$prechosen_version")

    # restrict to a particular build if selected
    elif [[ $prechosen_build ]]; then
        builds_available=$(grep -c build "$mist_export_file")
        build_found=0
        i=0
        while [[ $i -lt $builds_available ]]; do
            build_check=$(ljt $i.build < "$mist_export_file")
            if [[ "$build_check" == "$prechosen_build" ]]; then
                build_found=1
                break
            fi
            ((i++))
        done
        if [[ $build_found = 0 ]]; then
            writelog "[run_mist] ERROR: build is not available"
            echo
            exit 1
        fi
        writelog "[run_mist] Checking that selected build $prechosen_build is available"
        mist_args+=("$prechosen_build")

    # restrict to the same build as the system if selected
    elif [[ $samebuild == "yes" ]]; then
        # temporarily we will just check for the same version
        writelog "[run_mist] Checking that current version $system_version is available"
        mist_args+=("$system_version")

    else
        # if no version was selected, we want the latest available, which is the first in the mist-list
        latest_version=$(ljt '0.version' < "$mist_export_file")
        if [[ $latest_version ]]; then
            if ! is-at-least "$system_version" "$latest_version"; then
                writelog "[run_mist] ERROR: latest version in catalog ($latest_version) is older than the system version ($system_version)"
                echo
                exit 1
            fi
            writelog "[run_mist] Selected $latest_version as the latest version available"
            mist_args+=("$latest_version")
        else
            writelog "[run_mist] ERROR: mist was unable to locate any installers (probably no internet connection)"
            echo
            exit 1
        fi
    fi

    # grab package if --pkg selected and --move is not selected, otherwise we will grab the app
    if [[ $pkg_installer && ! $move_to_applications_folder ]]; then
        mist_args+=("package")
        mist_args+=("--package-name")
        mist_args+=("$default_downloaded_pkg_name")
        mist_args+=("--package-identifier")
        mist_args+=("$default_downloaded_pkg_id")
        mist_args+=("--output-directory")
        mist_args+=("$workdir")
    else
        mist_args+=("application")
        mist_args+=("--application-name")
        mist_args+=("$default_downloaded_app_name")
        mist_args+=("--output-directory")
        mist_args+=("$installer_directory")
    fi

    if [[ "$skip_validation" != "yes" ]]; then
        writelog "[run_mist] Setting mist to only list compatible installers"
        mist_args+=("--compatible")
    fi

    # run in no-ansi mode which is less pretty but better for our logs
    mist_args+=("--no-ansi")

    # reduce output if --quiet mode
    if [[ "$quiet" == "yes" ]]; then
        writelog "[run_mist] Setting mist to quiet mode"
        mist_args+=("--quiet")
    fi

    # optionally cache downloads to save time when doing repeated tests
    if [[ "$cache_downloads" == "yes" ]]; then
        writelog "[run_mist] Setting mist to cache downloads"
        mist_args+=("--cache-downloads")
    fi

    # optionally set mist to use a caching server
    if [[ "$caching_server" ]]; then
        writelog "[run_mist] Setting mist to use Caching Server $caching_server"
        mist_args+=("--caching-server")
        mist_args+=("$caching_server")
    fi

    # force overwrite of existing app or pkg of the same name
    # mist_args+=("--force")

    # set alternative catalog if selected
    if [[ $catalogurl ]]; then
        writelog "[run_mist] Non-standard catalog URL selected"
        mist_args+=("--catalog-url")
        mist_args+=("$catalogurl")
    elif [[ $catalog ]]; then
        darwin_version=$(get_darwin_from_os_version "$catalog")
        get_catalog
        writelog "[run_mist] Non-default catalog selected (darwin version $darwin_version)"
        mist_args+=("--catalog-url")
        mist_args+=("${catalogs[$darwin_version]}")
    fi

    # include betas if selected
    if [[ $beta == "yes" ]]; then
        writelog "[run_mist] Beta versions included"
        mist_args+=("--include-betas")
    fi

    # now run mist
    echo
    writelog "[run_mist] This command is now being run:"
    echo
    writelog "mist ${mist_args[*]}"

    if ! "$mist_bin" "${mist_args[@]}" ; then
        writelog "[run_mist] An error occurred running mist. Cannot continue."
        echo
        exit 1
    fi

    # Identify the downloaded installer
    downloaded_app=$( find "$installer_directory" -maxdepth 1 -name "Install macOS *.app" -type d -print -quit )
    downloaded_installer_pkg=$( find "$workdir" -maxdepth 1 -name "InstallAssistant-*-*.pkg" -type f -print -quit 2>/dev/null )

    if [[ -d "$downloaded_app" ]]; then
        downloaded_app_name=$(basename "$downloaded_app")
        writelog "[run_mist] $downloaded_app_name downloaded to $installer_directory."
        working_macos_app="$downloaded_app"
    elif [[ -f "$downloaded_installer_pkg" ]]; then
        downloaded_installer_pkg_name=$(basename "$downloaded_installer_pkg")
        writelog "[run_mist] $downloaded_installer_pkg_name downloaded to $workdir."
        working_installer_pkg="$downloaded_installer_pkg"
    else
        writelog "[run_mist] No installer found. I guess nothing got downloaded."
        exit 1
    fi
}


# -----------------------------------------------------------------------------
# Set localized values for user dialogues 
# -----------------------------------------------------------------------------
set_localisations() {
    # Grab the currently logged in user to set the language for all dialogue messages
    current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
    current_uid=$(/usr/bin/id -u "$current_user")

    # Get the proper home directory. We use this because the output of scutil might not 
    # reflect the canonical RecordName or the HomeDirectory at all, which might prevent
    # us from detecting the language
    current_user_homedir=$(/usr/libexec/PlistBuddy -c 'Print :dsAttrTypeStandard\:NFSHomeDirectory:0' /dev/stdin <<< "$(/usr/bin/dscl -plist /Search -read "/Users/${current_user}" NFSHomeDirectory)")
    # detect the user's language
    language=$(/usr/libexec/PlistBuddy -c 'print AppleLanguages:0' "/${current_user_homedir}/Library/Preferences/.GlobalPreferences.plist")
    # override language if specified in arguments
    if [[ "$language_override" ]]; then
        writelog "[set_localisations] Overriding language to $language_override"
        language="$language_override"
    else
        writelog "[set_localisations] Set language to $language"
    fi

    if [[ $language = de* ]]; then
        user_language="de"
    elif [[ $language = nl* ]]; then
        user_language="nl"
    elif [[ $language = fr* ]]; then
        user_language="fr"
    elif [[ $language = es* ]]; then
        user_language="es"
    elif [[ $language = pt* ]]; then
        user_language="pt"
    elif [[ $language = ja* ]]; then
        user_language="ja"
    elif [[ $language = ua* ]]; then
        user_language="ua"
    else
        user_language="en"
    fi

    # Dialogue localizations - download window - title
    dialog_dl_title_en="Downloading macOS"
    dialog_dl_title_de="macOS wird heruntergeladen"
    dialog_dl_title_nl="macOS downloaden"
    dialog_dl_title_fr="Téléchargement de macOS"
    dialog_dl_title_es="Descargando macOS"
    dialog_dl_title_pt="Baixando o macOS"
    dialog_dl_title_ja="macOS のダウンロード"
    dialog_dl_title_ua="Завантаження macOS"
    dialog_dl_title=dialog_dl_title_${user_language}

    # Dialogue localizations - download window - description
    dialog_dl_desc_en="We need to download the macOS installer to your computer.  \n\nThis may take several minutes, depending on your internet connection."
    dialog_dl_desc_de="Das macOS-Installationsprogramm wird heruntergeladen.  \n\nDies kann einige Minuten dauern, je nach Ihrer Internetverbindung."
    dialog_dl_desc_nl="We moeten het macOS besturingssysteem downloaden.  \n\nDit kan enkele minuten duren, afhankelijk van uw internetverbinding."
    dialog_dl_desc_fr="Nous devons télécharger le programme d'installation de macOS sur votre ordinateur.  \n\nCela peut prendre plusieurs minutes, en fonction de votre connexion Internet."
    dialog_dl_desc_es="Necesitamos descargar el instalador de macOS en tu Mac.  \n\nEsto puede tardar varios minutos, dependiendo de tu conexión a Internet."
    dialog_dl_desc_pt="Precisamos baixar o instalador do macOS para o seu computador. \n\nIsso pode levar vários minutos, dependendo da sua conexão com a Internet."
    dialog_dl_desc_ja="macOS のインストーラをダウンロードしています。  \n\n回線状況によっては数分かかる場合があります。"
    dialog_dl_desc_ua="«Нам потрібно завантажити програму встановлення macOS на ваш комп’ютер.  \n\nЦе може зайняти декілька хвилин, залежно від вашого інтернет-з’єднання."
    dialog_dl_desc=dialog_dl_desc_${user_language}

    # Dialogue localizations - erase lock screen - title
    dialog_erase_title_en="Erasing macOS"
    dialog_erase_title_de="macOS wiederherstellen"
    dialog_erase_title_nl="macOS herinstalleren"
    dialog_erase_title_fr="Effacement de macOS"
    dialog_erase_title_es="Borrado de macOS"
    dialog_erase_title_pt="Apagado de macOS"
    dialog_erase_title_ja="macOS の消去"
    dialog_erase_title_ua="Стирання macOS"
    dialog_erase_title=dialog_erase_title_${user_language}

    # Dialogue localizations - erase lock screen - description
    dialog_erase_desc_en="### Preparing the installer may take up to 30 minutes.  \n\nOnce completed your computer will reboot and continue the reinstallation."
    dialog_erase_desc_de="### Das Vorbereiten des Installationsprogramms kann bis zu 30 Minuten dauern.  \n\nNach Abschluss des Vorgangs wird Ihr Computer neu gestartet und die Neuinstallation fortgesetzt."
    dialog_erase_desc_nl="### Het voorbereiden van het installatieprogramma kan tot 30 minuten duren.  \n\nNa voltooiing zal uw computer opnieuw opstarten en de herinstallatie voortzetten."
    dialog_erase_desc_fr="### La préparation du programme d'installation peut prendre jusqu'à 30 minutes.  \n\nUne fois terminé, votre ordinateur redémarre et poursuit la réinstallation."
    dialog_erase_desc_es="### La preparación del instalador puede tardar hasta 30 minutos.  \n\nUna vez completado, tu Mac se reiniciará y continuará la reinstalación."
    dialog_erase_desc_pt="### A preparação do instalador pode levar até 30 minutos. \n\nDepois de concluído, seu computador será reiniciado e a reinstalação continuará."
    dialog_erase_desc_ja="### インストーラの準備には最大で30分かかる場合があります。  \n\n完了するとコンピュータが再起動し、再インストールが開始されます。"
    dialog_erase_desc_ua="### Підготовка інсталятора може тривати до 30 хвилин.  \n\nПісля завершення ваш комп'ютер перезавантажиться та продовжить перевстановлення."
    dialog_erase_desc=dialog_erase_desc_${user_language}

    # Dialogue localizations - reinstall lock screen - title
    dialog_reinstall_title_en="Upgrading macOS"
    dialog_reinstall_title_de="macOS aktualisieren"
    dialog_reinstall_title_nl="macOS upgraden"
    dialog_reinstall_title_fr="Mise à niveau de macOS"
    dialog_reinstall_title_es="Actualizando de macOS"
    dialog_reinstall_title_pt="Atualizando o macOS"
    dialog_reinstall_title_ja="macOS のアップグレード"
    dialog_reinstall_title_ua="Оновлення macOS"
    dialog_reinstall_title=dialog_reinstall_title_${user_language}

    # Dialogue localizations - reinstall lock screen - heading
    dialog_reinstall_heading_en="Please wait as we prepare your computer for upgrading macOS."
    dialog_reinstall_heading_de="Bitte warten Sie, während Ihren Computer für das Upgrade von macOS vorbereitet wird."
    dialog_reinstall_heading_nl="Even geduld terwijl we uw computer voorbereiden voor de upgrade van macOS."
    dialog_reinstall_heading_fr="Veuillez patienter pendant que nous préparons votre ordinateur pour la mise à niveau de macOS."
    dialog_reinstall_heading_es="Por favor, espera mientras preparamos tu mac para la actualización de macOS."
    dialog_reinstall_heading_pt="Aguarde enquanto preparamos seu computador para atualizar o macOS."
    dialog_reinstall_heading_ja="macOS アップグレードの準備をしています。しばらくお待ちください。"
    dialog_reinstall_heading_ua="Зачекайте, поки ми підготуємо ваш комп’ютер до оновлення macOS."
    dialog_reinstall_heading=dialog_reinstall_heading_${user_language}

    # Dialogue localizations - reinstall lock screen - description
    dialog_reinstall_desc_en="### Preparing the installer may take up to 30 minutes.  \n\nOnce completed your computer will reboot and begin the upgrade."
    dialog_reinstall_desc_de="### Dieser Prozess kann bis zu 30 Minuten benötigen.  \n\nDer Computer startet anschliessend neu und beginnt mit der Aktualisierung."
    dialog_reinstall_desc_nl="### Dit proces duurt ongeveer 30 minuten.  \n\nZodra dit is voltooid, wordt uw computer opnieuw opgestart en begint de upgrade."
    dialog_reinstall_desc_fr="### Ce processus peut prendre jusqu'à 30 minutes.  \n\nUne fois terminé, votre ordinateur redémarrera et commencera la mise à niveau."
    dialog_reinstall_desc_es="### La preparación del instalador puede tardar hasta 30 minutos.  \n\nUna vez completado, tu Mac se reiniciará y comenzará la actualización."
    dialog_reinstall_desc_pt="### A preparação do instalador pode levar até 30 minutos. \n\nDepois de concluído, seu computador será reiniciado e a atualização começará."
    dialog_reinstall_desc_ja="### インストーラの準備には最大で30分かかる場合があります。  \n\n完了するとコンピュータが再起動し、アップグレードが開始されます。"
    dialog_reinstall_desc_ua="### Підготовка інсталятора може тривати до 30 хвилин.  \n\nПісля завершення комп'ютер перезавантажиться та почнеться оновлення."
    dialog_reinstall_desc=dialog_reinstall_desc_${user_language}

    # Dialogue localizations - reinstall lock screen - status message
    dialog_reinstall_status_en="Preparing macOS for installation"
    dialog_reinstall_status_de="Vorbereiten von macOS für die Installation"
    dialog_reinstall_status_nl="MacOS voorbereiden voor installatie"
    dialog_reinstall_status_fr="Préparation de macOS pour l'installation"
    dialog_reinstall_status_es="Preparación de macOS para la instalación"
    dialog_reinstall_status_pt="Preparando o macOS para instalação"
    dialog_reinstall_status_ja="macOS インストールの準備"
    dialog_reinstall_status_ua="Підготовка macOS до встановлення"
    dialog_reinstall_status=dialog_reinstall_status_${user_language}

    # Dialogue localizations - reebooting screen - heading
    dialog_rebooting_heading_en="The upgrade is now ready for installation.  \n\n### Save any open work now!"
    dialog_rebooting_heading_de="Die macOS-Aktualisierung steht nun zur Installation bereit.  \n\n### Speichern Sie jetzt alle offenen Arbeiten ab!"
    dialog_rebooting_heading_nl="De upgrade is nu klaar voor installatie.  \n\n### Bewaar nu al het open werk!"
    dialog_rebooting_heading_fr="La mise à niveau est maintenant prête à être installée.  \n\n### Sauvegardez les travaux en cours maintenant!"
    dialog_rebooting_heading_es="La actualización ya está lista para ser instalada.  \n\n### ¡Guarda ahora los trabajos pendientes!"
    dialog_rebooting_heading_pt="A atualização agora está pronta para instalação. \n\n### Salve qualquer trabalho aberto agora!"
    dialog_rebooting_heading_ja="アップグレードのインストール準備ができました。  \n\n### 開いているファイルがあれば保存してください！"
    dialog_rebooting_heading_ua="Тепер оновлення готове до встановлення.  \n\n### Збережіть будь-яку відкриту роботу зараз!"
    dialog_rebooting_heading=dialog_rebooting_heading_${user_language}

    # Dialogue localizations - erase confirmation window - description
    dialog_erase_confirmation_desc_en="Please confirm that you want to ERASE ALL DATA FROM THIS DEVICE and reinstall macOS"
    dialog_erase_confirmation_desc_de="Bitte bestätigen Sie, dass Sie ALLE DATEN VON DIESEM GERÄT LÖSCHEN und macOS neu installieren wollen!"
    dialog_erase_confirmation_desc_nl="Weet je zeker dat je ALLE GEGEVENS VAN DIT APPARAAT WILT WISSEN en macOS opnieuw installeert?"
    dialog_erase_confirmation_desc_fr="Veuillez confirmer que vous souhaitez EFFACER TOUTES LES DONNÉES DE CET APPAREIL et réinstaller macOS"
    dialog_erase_confirmation_desc_es="Por favor, confirma que deseas BORRAR TODOS LOS DATOS DE ESTE DISPOSITIVO y reinstalar macOS"
    dialog_erase_confirmation_desc_pt="Confirme que deseja APAGAR TODOS OS DADOS DESTE DISPOSITIVO e reinstalar o macOS"
    dialog_erase_confirmation_desc_ja="***このデバイスから全てのデータが消去***され、macOS が再インストールされます。ご確認ください。"
    dialog_erase_confirmation_desc_ua="Будь ласка, підтвердіть, що ви хочете ВИДАЛИТИ ВСІ ДАНІ З ЦЬОГО ПРИСТРОЮ та переінсталювати macOS"
    dialog_erase_confirmation_desc=dialog_erase_confirmation_desc_${user_language}

    # Dialogue localizations - reinstall confirmation window - description
    dialog_reinstall_confirmation_desc_en="Please confirm that you want to upgrade macOS on this system now"
    dialog_reinstall_confirmation_desc_de="Bitte bestätigen Sie, dass Sie macOS auf diesem System jetzt aktualisieren möchten."
    dialog_reinstall_confirmation_desc_nl="Bevestig dat u macOS op dit systeem nu wilt updaten"
    dialog_reinstall_confirmation_desc_fr="Veuillez confirmer que vous voulez mettre à jour macOS sur ce système maintenant."
    dialog_reinstall_confirmation_desc_es="Por favor, confirma que deseas actualizar macOS en este sistema ahora"
    dialog_reinstall_confirmation_desc_pt="Confirme que deseja atualizar o macOS neste sistema agora"
    dialog_reinstall_confirmation_desc_ja="このシステムで macOS をアップグレードすることをご確認ください。"
    dialog_reinstall_confirmation_desc_ua="Будь ласка, підтвердіть, що ви хочете оновити macOS на цій системі зараз"
    dialog_reinstall_confirmation_desc=dialog_reinstall_confirmation_desc_${user_language}

    # Dialogue localizations - free space check - description
    dialog_check_desc_en="The macOS upgrade cannot be installed as there is not enough space left on the drive."
    dialog_check_desc_de="macOS kann nicht aktualisiert werden, da nicht genügend Speicherplatz auf dem Laufwerk frei ist."
    dialog_check_desc_nl="De upgrade van macOS kan niet worden geïnstalleerd omdat er niet genoeg ruimte is op de schijf."
    dialog_check_desc_fr="La mise à niveau de macOS ne peut pas être installée car il n'y a pas assez d'espace disponible sur ce volume."
    dialog_check_desc_es="La actualización de macOS no se puede instalar porque no queda espacio suficiente en la unidad."
    dialog_check_desc_pt="A atualização do macOS não pode ser instalada porque não há espaço suficiente na unidade."
    dialog_check_desc_ja="ドライブに十分な空き領域がないため、macOS アップグレードをインストールできません。"
    dialog_check_desc_ua="Оновлення macOS не вдається встановити, оскільки на диску залишилось недостатньо місця."
    dialog_check_desc=dialog_check_desc_${user_language}

    # Dialogue localizations - power check - title
    dialog_power_title_en="Waiting for AC Power Connection"
    dialog_power_title_de="Auf Netzteil warten"
    dialog_power_title_nl="Wachten op stroomadapter"
    dialog_power_title_fr="En attente de l'alimentation secteur"
    dialog_power_title_es="A la espera de la conexión a la red eléctrica"
    dialog_power_title_pt="Aguardando conexão de alimentação CA"
    dialog_power_title_ja="電源アダプタの接続を待っています"
    dialog_power_title_ua="Очікування підключення зарядного пристрою"
    dialog_power_title=dialog_power_title_${user_language}

    # Dialogue localizations - power check - description
    dialog_power_desc_en="Please connect your computer to power using an AC power adapter.  \n\nThis process will continue if AC power is detected within the specified time."
    dialog_power_desc_de="Bitte verbinden Sie Ihren Computer mit einem Netzteil.  \n\nDieser Prozess wird fortgesetzt, wenn eine Stromversorgung innerhalb der folgenden Zeit erkannt wird:"
    dialog_power_desc_nl="Sluit uw computer aan met de stroomadapter.  \n\nZodra deze is gedetecteerd gaat het proces verder binnen de volgende:"
    dialog_power_desc_fr="Veuillez connecter votre ordinateur à un adaptateur secteur.  \n\nCe processus se poursuivra une fois que l'alimentation secteur sera détectée dans la suivante:"
    dialog_power_desc_es="Conecta tu Mac a la corriente eléctrica mediante un adaptador de CA.  \n\nEste proceso continuará si se detecta alimentación de CA dentro del tiempo especificado."
    dialog_power_desc_pt="Conecte seu computador à energia usando um adaptador de energia CA. \in\Este processo continuará se a alimentação CA for detectada dentro do tempo especificado."
    dialog_power_desc_ja="コンピュータに電源アダプタを接続してください。  \n\n指定された時間内に電源アダプタが接続された場合、この処理は続行されます。"
    dialog_power_desc_ua="Будь ласка, підключіть комп'ютер до мережі за допомогою зарядного пристрою.   \n\nЦей процес буде продовжено, якщо протягом зазначеного часу буде підключено зарядний пристрій."
    dialog_power_desc=dialog_power_desc_${user_language}

    # Dialogue localizations - no power detected - description
    dialog_nopower_desc_en="### AC power was not connected in the specified time.  \n\nPress OK to quit."
    dialog_nopower_desc_de="### Die Netzspannung wurde nicht in der angegebenen Zeit angeschlossen.  \n\nZum Beenden OK drücken."
    dialog_nopower_desc_nl="### De netspanning was niet binnen de opgegeven tijd aangesloten.  \n\nDruk op OK om af te sluiten."
    dialog_nopower_desc_fr="### Le courant alternatif n'a pas été branché dans le délai spécifié.  \n\nAppuyez sur OK pour quitter."
    dialog_nopower_desc_es="### La alimentación de CA no se ha conectado en el tiempo especificado.  \n\nPulsa OK para salir."
    dialog_nopower_desc_pt="### A alimentação CA não foi conectada no tempo especificado. \n\nPressione OK para sair."
    dialog_nopower_desc_ja="### 指定された時間内に電源アダプタが接続されませんでした。  \n\nOK を押して終了してください。"
    dialog_nopower_desc_ua="### Зарядний пристрій не було підключено вчасно  \n\nНатисніть OK, щоб вийти." 
    dialog_nopower_desc=dialog_nopower_desc_${user_language}

    # Dialogue localizations - Find My check - title
    dialog_fmm_title_en="Waiting for Find My Mac to be disabled"
    dialog_fmm_title_de="Warte auf die Deaktivierung von «Meinen Mac suchen»"
    dialog_fmm_title_nl="Wachten op Vind mijn Mac"
    dialog_fmm_title_fr="En attente de Localiser mon Mac"
    dialog_fmm_title_es="A la espera de la desactivacion de Buscar mi Mac"
    dialog_fmm_title_pt="Aguardando que o Buscar no Mac seja desativado"  
    dialog_fmm_title_ja="「Macを探す」が無効になるのを待っています"
    dialog_fmm_title_ua="Очікування вимкнення функції Find My Mac"
    dialog_fmm_title=dialog_fmm_title_${user_language}

    # Dialogue localizations - Find My check - description
    dialog_fmm_desc_en="Please disable **Find My Mac** in your iCloud settings.  \n\nThis setting can be found in **System Preferences** > **Apple ID** > **iCloud**.  \n\nThis process will continue if Find My has been disabled within the specified time."
    dialog_fmm_desc_de="Bitte deaktiviere **«Meinen Mac suchen»** in Ihren iCloud-Einstellungen.  \n\nDiese Einstellung finden Sie in **Systemeinstellungen** > **Apple ID** > **iCloud**.  \n\nDieser Vorgang wird fortgesetzt, wenn «Meinen Mac suchen» innerhalb der angegebenen Zeit deaktiviert wurde."
    dialog_fmm_desc_nl="Schakel **Vind mijn Mac** uit in uw iCloud-instellingen.  \n\nDeze instelling vindt u in **Systeemvoorkeuren** > **Apple ID** > **iCloud**.  \n\nDit proces wordt voortgezet als **Vind mijn Mac** binnen de opgegeven tijd is uitgeschakeld."
    dialog_fmm_desc_fr="Veuillez désactiver **Localiser mon Mac** dans vos paramètres iCloud.  \n\nCe paramètre se trouve dans **Préférences système** > **Identifiant Apple** > **iCloud**.  \n\nCe processus se poursuivra si Localiser mon Mac a été désactivé dans le délai spécifié."
    dialog_fmm_desc_es="Por favor desactiva **Buscar mi Mac** en los ajustes de iCloud.  \n\nEste ajuste se encuentra en **Preferencias del sistema** > **ID de Apple** > **iCloud**.  \n\nEste proceso continuará si Buscar mi Mac se ha desactivado dentro del tiempo especificado."
    dialog_fmm_desc_pt="Desative **Buscar no Mac** nas configurações do iCloud. \n\nEssa configuração pode ser encontrada em **Preferências do Sistema** > **ID Apple** > **iCloud**. \n\nEsse processo continuará se o Buscar no Mac tiver sido desativado dentro do tempo especificado." 
    dialog_fmm_desc_ja="iCloud の設定で「**Macを探す**」を無効にしてください。  \nこの設定は **システム環境設定** > **Apple ID** > **iCloud** にあります。  \n\n指定された時間内に「Macを探す」が無効になった場合、この処理は続行されます。"
    dialog_fmm_desc_ua="Будь ласка, вимкніть **Find My Mac** у налаштуваннях iCloud.  \n\nЦей параметр можна знайти в **Системні налаштування** > **Apple ID** > **iCloud**.  \n\nЦей процес продовжиться, якщо функцію «Find My Mac» буде вимкнено протягом зазначеного часу."
    dialog_fmm_desc=dialog_fmm_desc_${user_language}

    # Dialogue localizations - Find My check failed - description
    dialog_fmmenabled_desc_en="### Find My Mac was not disabled in the specified time.  \n\nPress OK to quit."
    dialog_fmmenabled_desc_de="### «Meinem Mac suchen» wurde nicht innerhalb der angegebenen Zeit deaktiviert.  \n\nZum Beenden OK drücken."
    dialog_fmmenabled_desc_nl="### Vind mijn Mac was niet uitgeschakeld in de opgegeven tijd.  \n\nDruk op OK om af te sluiten."
    dialog_fmmenabled_desc_fr="### Localiser mon Mac n'a pas été désactivé dans le temps imparti.  \n\nAppuyez sur OK pour quitter."
    dialog_fmmenabled_desc_es="### Buscar mi Mac no se ha desactivado en el tiempo especificado.  \n\nPulsa OK para salir."
    dialog_fmmenabled_desc_pt="### Buscar no Mac não foi desativado no tempo especificado. \n\nPressione OK para sair."
    dialog_fmmenabled_desc_ja="### 「Macを探す」は指定された時間内に無効になりませんでした。  \n\nOK を押して終了してください。"
    dialog_fmmenabled_desc_ua="### Find My Mac не було вимкнено вчасно. \n\nНатисніть OK, щоб вийти."
    dialog_fmmenabled_desc=dialog_fmmenabled_desc_${user_language}

    # Dialogue localizations - ask for credentials - erase
    dialog_erase_credentials_en="Erasing macOS requires authentication using local account credentials.  \n\nPlease enter your account name and password to start the erase process."
    dialog_erase_credentials_de="Das Löschen von macOS erfordert eine Authentifizierung mit den Anmeldedaten des lokalen Kontos.  \n\nBitte geben Sie Ihren Kontonamen und Ihr Passwort ein, um den Löschvorgang zu starten."
    dialog_erase_credentials_nl="Voor het wissen van macOS is verificatie met behulp van lokale accountgegevens vereist.  \n\nVoer uw accountnaam en wachtwoord in om het wisproces te starten."
    dialog_erase_credentials_fr="L'effacement de macOS nécessite une authentification à l'aide des informations d'identification du compte local.  \n\nVeuillez saisir votre nom de compte et votre mot de passe pour lancer le processus d'effacement."
    dialog_erase_credentials_es="El borrado de macOS requiere la autenticación mediante las credenciales de la cuenta de usuario local.  \n\nIntroduce tu nombre de usuario y contraseña para iniciar el proceso de borrado."
    dialog_erase_credentials_pt="Apagar o macOS requer autenticação usando credenciais de conta local. \n\nDigite seu nome de conta e senha para iniciar o processo de exclusão."
    dialog_erase_credentials_ja="macOS を消去するには、ローカルアカウントの資格情報による認証が必要です。  \n\nアカウント名とパスワードを入力して消去を開始してください。"
    dialog_erase_credentials_ua="Видалення macOS вимагає автентифікації за допомогою локальних облікових даних.  \n\nБудь ласка, введіть ім'я та пароль вашого облікового запису, щоб розпочати процес стирання."
    dialog_erase_credentials=dialog_erase_credentials_${user_language}

    # Dialogue localizations - ask for credentials - reinstall
    dialog_reinstall_credentials_en="Upgrading macOS requires authentication using local account credentials.  \n\nPlease enter your account name and password to start the upgrade process."
    dialog_reinstall_credentials_de="Das Upgrade von macOS erfordert eine Authentifizierung mit den Anmeldedaten des lokalen Kontos.  \n\nBitte geben Sie Ihren Kontonamen und Ihr Passwort ein, um den Upgrade-Prozess zu starten."
    dialog_reinstall_credentials_nl="Voor het upgraden van macOS is verificatie met behulp van lokale accountgegevens vereist.  \n\nVoer uw accountnaam en wachtwoord in om het upgradeproces te starten."
    dialog_reinstall_credentials_fr="La mise à niveau de macOS nécessite une authentification à l'aide des informations d'identification du compte local.  \n\nVeuillez saisir votre nom de compte et votre mot de passe pour lancer le processus de mise à niveau."
    dialog_reinstall_credentials_es="La actualización de macOS requiere la autenticación mediante las credenciales de la cuenta de usuario local.  \n\nIntroduce el nombre de tu usuario y la contraseña para iniciar el proceso de actualización."
    dialog_reinstall_credentials_pt="A atualização do macOS requer autenticação usando credenciais de conta local. \n\nDigite seu nome de conta e senha para iniciar o processo de atualização."
    dialog_reinstall_credentials_ja="macOS をアップグレードするには、ローカルアカウントの資格情報による認証が必要です。  \n\nアカウント名とパスワードを入力してアップグレードを開始してください。"
    dialog_reinstall_credentials_ua="Оновлення macOS вимагає автентифікації за допомогою локальних облікових даних.  \n\nБудь ласка, введіть ім'я та пароль вашого облікового запису, щоб розпочати процес оновлення."
    dialog_reinstall_credentials=dialog_reinstall_credentials_${user_language}

    # Dialogue localizations - not a volume owner
    dialog_not_volume_owner_en="### Account is not a Volume Owner  \n\nPlease login using one of the following accounts and try again."
    dialog_not_volume_owner_de="### Konto ist kein Volume-Besitzer  \n\nBitte melden Sie sich mit einem der folgenden Konten an und versuchen Sie es erneut."
    dialog_not_volume_owner_nl="### Account is geen volume-eigenaar  \n\nLog in met een van de volgende accounts en probeer het opnieuw."
    dialog_not_volume_owner_fr="### Le compte n'est pas propriétaire du volume  \n\nVeuillez vous connecter en utilisant l'un des comptes suivants et réessayer."
    dialog_not_volume_owner_es="### La cuenta de usuario no es un Volume Owner   \n\nPor favor, inicie sesión con una de las siguientes cuentas de usuario e inténtelo de nuevo."
    dialog_not_volume_owner_pt="### A conta não é um Volume Owner \n\nFaça login usando uma das contas a seguir e tente novamente."
    dialog_not_volume_owner_ja="### アカウントがボリュームのオーナーではありません  \n\n次のいずれかのアカウントで再度ログインをお試しください。"
    dialog_not_volume_owner_ua="### Обліковий запис не є Власником тому  \n\nБудь ласка, увійдіть за допомогою одного з наступних облікових записів і спробуйте ще раз."
    dialog_not_volume_owner=dialog_not_volume_owner_${user_language}

    # Dialogue localizations - invalid user
    dialog_invalid_user_en="### Incorrect user  \n\nThis account cannot be used to to perform the reinstall"
    dialog_invalid_user_de="### Falsche Benutzer  \n\nDieses Konto kann nicht zur Durchführung der Neuinstallation verwendet werden"
    dialog_invalid_user_nl="### Incorrecte account  \n\nDit account kan niet worden gebruikt om de herinstallatie uit te voeren"
    dialog_invalid_user_fr="### Mauvais utilisateur  \n\nCe compte ne peut pas être utilisé pour effectuer la réinstallation"
    dialog_invalid_user_es="### Usuario incorrecto  \n\nEsta cuenta de usuario no puede ser utilizada para realizar la reinstalación"
    dialog_invalid_user_pt="### Usuário incorreto \n\nEsta conta não pode ser usada para realizar a reinstalação"
    dialog_invalid_user_ja="### ユーザーが間違っています  \n\nこのアカウントでは再インストールを実行できません"
    dialog_invalid_user_ua="### Неправильний користувач  \n\nЦей обліковий запис не може бути використаний для перевстановлення"
    dialog_invalid_user=dialog_invalid_user_${user_language}

    # Dialogue localizations - invalid password
    dialog_invalid_password_en="### Incorrect password  \n\nThe password entered is NOT the login password for"
    dialog_invalid_password_de="### Falsches Passwort  \n\nDas eingegebene Passwort ist NICHT das Anmeldepasswort für"
    dialog_invalid_password_nl="### Incorrect wachtwoord  \n\nHet ingevoerde wachtwoord is NIET het inlogwachtwoord voor"
    dialog_invalid_password_fr="### Mot de passe erroné  \n\nLe mot de passe entré n'est PAS le mot de passe de connexion pour"
    dialog_invalid_password_es="### Contraseña incorrecta  \n\nLa contraseña introducida NO es la contraseña de acceso a"
    dialog_invalid_password_pt="### Senha incorreta \n\nA senha digitada NÃO é a senha de login para"
    dialog_invalid_password_ja="### パスワードが間違っています  \n\n入力されたパスワードは、このアカウントのログインパスワードではありません"
    dialog_invalid_password_ua="### Неправильний пароль  \n\nВведений пароль НЕ є паролем для входу до"
    dialog_invalid_password=dialog_invalid_password_${user_language}

    # Dialogue localizations - buttons - confirm
    dialog_confirmation_button_en="Confirm"
    dialog_confirmation_button_de="Bestätigen"
    dialog_confirmation_button_nl="Bevestig"
    dialog_confirmation_button_fr="Confirmer"
    dialog_confirmation_button_es="Confirmar"
    dialog_confirmation_button_pt="Confirmar"
    dialog_confirmation_button_ja="確認"
    dialog_confirmation_button_ua="Підтвердити"
    dialog_confirmation_button=dialog_confirmation_button_${user_language}

    # Dialogue localizations - buttons - cancel
    dialog_cancel_button_en="Cancel"
    dialog_cancel_button_de="Abbrechen"
    dialog_cancel_button_nl="Annuleren"
    dialog_cancel_button_fr="Annuler"
    dialog_cancel_button_es="Cancelar"
    dialog_cancel_button_pt="Cancelar"
    dialog_cancel_button_ja="キャンセル"
    dialog_cancel_button_ua="Скасувати"
    dialog_cancel_button=dialog_cancel_button_${user_language}

    # Dialogue localizations - buttons - enter
    dialog_enter_button_en="Enter"
    dialog_enter_button_de="Eingeben"
    dialog_enter_button_nl="Enter"
    dialog_enter_button_fr="Entrer"
    dialog_enter_button_es="Entrar"
    dialog_enter_button_pt="Digitar"
    dialog_enter_button_ja="実行"
    dialog_enter_button_ua="Гаразд"
    dialog_enter_button=dialog_enter_button_${user_language}

    
}

# -----------------------------------------------------------------------------
# Usage message
# -----------------------------------------------------------------------------
show_help() {
    echo
    /bin/cat << HELP
    $script_name v$version, a script by @GrahamRPugh

    Please note that network access is required to Apple's software catalogs at ALL stages of this
    script's workflow - that includes BOTH download AND preparation stages. Please check that you are not
    running any kind of security / firewall software that may prevent this traffic.

    You must also not be restricting the execution of a macOS installer application in any way 
    (e.g. Jamf Software Restriction, Santa etc.).

    Common usage:
    [sudo] ./$script_name.sh [options]

    Standard options for list, download, reinstall and erase: 

    --list              List available updates only (don't download anything)
    [no flags]          Finds latest current production, non-forked version
                        of macOS, downloads it.
    --move              Moves the downloaded macOS installer to $installer_directory
    --reinstall         After download, reinstalls macOS without erasing the
                        current system
    --erase             After download, erases the current system
                        and reinstalls macOS.
    --confirm           Displays a confirmation dialog prior to erasing or reinstalling macOS.
    --check-power       Checks for AC power if set.
    --power-wait-limit NN
                        Maximum seconds to wait for detection of AC power, if
                        --check-power is set. Default is 60.
    --min-battery NN    If supplied along with --check-power, check for power is skipped if the 
                        battery is at a higher percentage than NN%.
    --check-fmm         Prompt the user to disable Find My Mac before proceeding, when using --erase
    --fmm-wait-limit NN Maximum seconds to wait for removal of Find My Mac, if
                        --check-fmm is set. Default is 300.
    --cleanup-after-use Creates a LaunchDaemon to delete $workdir after use. Mainly useful
                        in conjunction with the --reinstall option.

    Options for filtering which installer to download/use:

    --os NN | Name      Finds a specific inputted major macOS version if available
                        and downloads it if so. Will choose the latest matching build.
                        The name of the OS can be alternatively supplied, e.g. Sonoma
                        or "macOS Sonoma"
    --version NN.Y.Z    Finds a specific inputted minor version of macOS if available
                        and downloads it if so. Will choose the latest matching build.
    --build XYZ         Finds a specific inputted build of macOS if available
                        and downloads it if so.
    --sameos            Finds the version of macOS that matches the
                        existing system version, downloads it. Most useful with --erase.
    --samebuild         Finds the build of macOS that matches the
                        existing system version, downloads it. Most useful with --erase.
    --update            Checks that an existing installer on the system is still the most current
                        valid build, and if not, it will delete it and download the current installer.
    --replace-invalid   Checks that an existing installer on the system is still valid
                        i.e. would successfully build on this system. If not, deletes it
                        and downloads the current installer within the limits set by --os or --version.
    --overwrite         Delete any existing macOS installer found in $installer_directory and download
                        the current installer within the limits set by --os or --version.

    Options for dialogs:

    --confirmation-icon Set a custom confirmation icon
    --icon-size         Set the icon size in dialogs

    Advanced options:

    --clear-cache-only  When used in conjunction with --overwrite, --update or --replace-invalid,
                        the existing installer is removed but not replaced. This is useful
                        for running the script after an upgrade to clear the working files.
    --newvolumename     If using the --erase option, lets you customize the name of the
                        clean volume. Default is 'Macintosh HD'.
    --preinstall-command 'some arbitrary command'
                        Supply a shell command to run immediately prior to startosinstall
                        running. An example might be 'jamf recon -department Spare'.
                        Ensure that the command is in quotes.
    --postinstall-command 'some arbitrary command'
                        Supply a shell command to run immediately after startosinstall
                        completes preparation, but before reboot.
                        An example might be 'jamf recon -department Spare'.
                        Ensure that the command is in quotes.
    --catalog ...       Override the default catalog with one from a different OS.
    --catalogurl ...    Select a non-standard catalog URL.
    --caching-server ...
                        Set mist-cli to use a Caching Server, specifying the URL to the server.
    --pkg               Creates a package from the installer. Ignored if --move, --erase or --reinstall is selected.
                        Note that mist takes a long time to build the package from the complete installer, so
                        this method is not recommended for normal workflows.
    --keep-pkg          Retains a cached package if --move is used to extract an installer from it.
    --fs                Uses full-screen windows for all stages, not just the
                        preparation phase.
    --no-fs             Replaces the full-screen dialog window with a smaller dialog during the preparation
                        phase, so you can still access the desktop while the script runs.
    --beta              Include beta versions in the search. Works with the no-flag
                        (i.e. automatic), --os and --version arguments.
    --path /path/to     Overrides the destination of --move to a specified directory
    --min-drive-space   Override the default minimum space required for startosinstall
                        to run (45 GB).
    --no-curl           Prevents the download of swiftDialog, mist and icons in case your
                        security team don't like it.
    --no-timeout        The script will normally timeout if the installer has not successfully
                        prepared after 1 hour. This extends that time limit to 24 hours.
    --language          Override the system language with one of the other available languages.
                        Acceptable values are en, de, fr, nl, es, pt, ja.
    --cloneuser         Copy account settings for the user when installing 
                        to a new volume. For use with the --erase option.

    Extra packages:
        startosinstall --eraseinstall can install packages after the new installation. 
        By default, erase-install.sh will look for packages in $workdir/extras. 

    --extras /path/to   Overrides the path to search for extra packages

    Parameters for use with Apple Silicon Mac:
        Note that startosinstall requires user authentication on AS Mac. The user
        must have a Secure Token. This script checks for the Secure Token of the
        current user, but the user can be overridden via the dialog. 
        A dialog is used to supply the password, so this script cannot be run at the 
        login window or from remote terminal.

    --max-password-attempts NN | infinite
                        Overrides the default of 5 attempts to ask for the user's password. Using
                        'infinite' will disable the Cancel button and asking until the password is
                        successfully verified.
    --user              Override the user (the default is the current user).
    --very-insecure-mode
                        Invokes passwordless upgrades, for use with lab machines. NOT RECOMMENDED UNLESS
                        YOU CAN GUARANTEE PHYSICAL AND REMOTE SECURITY ON THE COMPUTER IN QUESTION.
    --credentials       A base64 credential set. Only works in conjunction with --very-insecure-mode

    Experimental features:

    --fetch-full-installer | --ffi | -f
                        Obtain the installer using 'softwareupdate --fetch-full-installer' method instead of
                        using mist-cli. 
    --list              List installers using 'softwareupdate --list-full-installers' when
                        called with --fetch-full-installer
    --seed ...          Select a non-standard seed program. This is only used with --fetch-full-installer 
                        options.
    --rebootdelay NN    Delays the reboot after preparation has finished by NN seconds (max 300)
                        (--reinstall option only)
    --kc                Keychain containing a user password (do not use the login keychain!!)
    --kc-pass           Password to open the keychain
    --kc-service        The name of the key containing the account and password
    --silent            Silent mode. No dialogs. Requires use of keychain (--kc mode) for Apple Silicon 
                        to provide a password, or the --credentials/--very-insecure-mode mode.
    --check-activity    If certain activity is detected, the script exits. Currently only supports 
                        Zoom meetings and Slack huddles.
    --quiet             Remove output from mist during installer download. Note that no progress 
                        is shown.
    --preservecontainer Preserves other volumes in your APFS container when using --erase
    --set-securebootlevel 
                        Resets Secure Boot Level to High when using --erase
    --clear-firmware    Clears the firmware NVRAM variables when using --erase

    Parameters useful in testing this script:

    --test-run          Run through the script right to the end, but do not actually
                        run the 'startosinstall' command. The command that would be
                        run is shown in stdout.
    --workdir /path/to  Supply an alternative working directory. The default is the same
                        directory in which erase-install.sh is saved.
    --cache-downloads   Caches mist downloads in a temporary directory in /private/tmp/com.ninxsoft.mist
                        Useful when running repeated tests.
HELP
    exit
}

# -----------------------------------------------------------------------------
# Return code 143 and finish the script when TERMinated or INTerrupted
# -----------------------------------------------------------------------------
# shellcheck disable=SC2317
terminate() {
    writelog "[terminate] Script was interrupted (last exit code was $?)"
    exit 143
}

# -----------------------------------------------------------------------------
# Unpack an installer package to the Applications folder
# -----------------------------------------------------------------------------
unpack_pkg_to_applications_folder() {
    # if dealing with a package we now have to extract it and check it's valid
    if [[ -f "$working_installer_pkg" ]]; then
        writelog "[unpack_pkg_to_applications_folder] Unpacking $working_installer_pkg into /Applications folder"
        if /usr/sbin/installer -pkg "$working_installer_pkg" -tgt / ; then
            working_macos_app=$( find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null )
            if [[ -d "$working_macos_app" && "$keep_pkg" != "yes" ]]; then
                writelog "[unpack_pkg_to_applications_folder] Deleting $working_installer_pkg"
                rm -f "$working_installer_pkg"
                working_installer_pkg=""
            fi
        else
            writelog "[unpack_pkg_to_applications_folder] ERROR - $working_installer_pkg could not be unpacked"
            exit 1
        fi
    fi
}

# -----------------------------------------------------------------------------
# Open dialog to show that the user is not valid for authenticating 
# startosinstall
# This is required on Apple Silicon Mac
# -----------------------------------------------------------------------------
user_is_invalid() {
    # required for Silicon Macs
    writelog "[user_is_invalid] ERROR - user was not validated."
    if [[ ! $silent ]]; then
        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        dialog_args+=(
            "--title"
            "${dialog_window_title}"
            "--icon"
            "${dialog_warning_icon}"
            "--iconsize"
            "${dialog_icon_size}"
            "--overlayicon"
            "SF=person.fill.xmark,colour=red"
            "--message"
            "${(P)dialog_invalid_user}"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null
    fi
}

# -----------------------------------------------------------------------------
# Open dialog to show that the password is not valid
# This is required on Apple Silicon Mac
# -----------------------------------------------------------------------------
password_is_invalid() {
    # required for Silicon Macs
    writelog "[password_is_invalid] ERROR - password is invalid."
    if [[ ! $silent ]]; then
        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        dialog_args+=(
            "--title"
            "${dialog_window_title}"
            "--icon"
            "${dialog_confirmation_icon}"
            "--iconsize"
            "${dialog_icon_size}"
            "--overlayicon"
            "SF=person.fill.xmark,colour=red"
            "--message"
            "${(P)dialog_invalid_password} $user"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null
    fi
}

# -----------------------------------------------------------------------------
# Open dialog to show that the user is not a Volume Owner.
# This is required on Apple Silicon Mac
# -----------------------------------------------------------------------------
# shellcheck disable=SC2317
user_not_volume_owner() {
    # required for Silicon Macs
    writelog "[user_is_invalid] ERROR - user is not a Volume Owner."
    if [[ ! $silent ]]; then
        # set the dialog command arguments
        get_default_dialog_args "utility"
        dialog_args=("${default_dialog_args[@]}")
        dialog_args+=(
            "--title"
            "${dialog_window_title}"
            "--icon"
            "${dialog_warning_icon}"
            "--iconsize"
            "${dialog_icon_size}"
            "--overlayicon"
            "SF=person.fill.xmark,colour=red"
            "--message"
            "$account_shortname ${(P)dialog_not_volume_owner}: ${enabled_users}"
        )
        # run the dialog command
        "$dialog_bin" "${dialog_args[@]}" 2>/dev/null
    fi
}

# -----------------------------------------------------------------------------
# Add context to log messages
# -----------------------------------------------------------------------------
writelog() {
    DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    echo "$DATE | v$version | $1"
}

# =============================================================================
# Main Body 
# =============================================================================

# autoload is-at-least module for version comparisons
autoload is-at-least

# ensure the finish function is executed when exit is signaled
trap "finish" EXIT

# ensure the finish function is executed and an error code is returned when the script is TERMinated or INTerrupted
trap "terminate" SIGINT SIGTERM

# ensure some cleanup is done after startosinstall is run (thanks @frogor!)
trap "post_prep_work" SIGUSR1

# Safety mechanism to prevent unwanted wipe while testing
erase="no"
reinstall="no"

# default minimum drive space in GB
# Note that the amount of space required varies between macOS installer and system versions.
# Override this default value with the --min-drive-space option.
min_drive_space=45

# default max_password_attempts to 5
max_password_attempts=5

# predefine arrays
preinstall_command=()
postinstall_command=()

# print out all the arguments
all_args="$*"

while test $# -gt 0 ; do
    case "$1" in
        -r|--reinstall) 
            reinstall="yes"
            ;;
        -e|--erase) erase="yes"
            ;;
        -m|--move) move="yes"
            ;;
        -s|--samebuild) samebuild="yes"
            ;;
        -t|--sameos) sameos="yes"
            ;;
        -o|--overwrite) overwrite="yes"
            ;;
        -x|--replace-invalid) replace_invalid_installer="yes"
            ;;
        -u|--update) update_installer="yes"
            ;;
        -c|--confirm) confirm="yes"
            ;;
        --check-activity) check_for_activity="yes"
            ;;
        --beta) beta="yes"
            ;;
        --preservecontainer) preservecontainer="yes"
            ;;
        -f|--ffi|--fetch-full-installer) ffi="yes"
            ;;
        -l|--list) list="yes"
            ;;
        --silent) silent="yes"
            ;;
        --pkg) pkg_installer="yes"
            ;;
        --keep-pkg) keep_pkg="yes"
            ;;
        --no-curl) no_curl="yes"
            ;;
        --no-timeout) no_timeout="yes"
            ;;
        --dialog-on-download) dl_dialog="yes"
            ;;
        --no-fs) no_fs="yes"
            ;;
        --fs) fs="yes"
            ;;
        --skip-validation) skip_validation="yes"
            ;;
        --user)
            shift
            account_shortname="$1"
            ;;
        --max-password-attempts)
            shift
            if [[ ( $1 == "infinite" ) || ( $1 -gt 0 ) ]]; then
                max_password_attempts="$1"
            fi
            ;;
        --rebootdelay)
            shift
            rebootdelay="$1"
            if [[ $rebootdelay -gt 300 ]]; then
                rebootdelay=300
            fi
            ;;
        --test-run) test_run="yes"
            ;;
        --caching-server)
            shift
            caching_server="$1"
            ;;
        --cache-downloads) cache_downloads="yes"
            ;;
        --clear-cache-only) clear_cache="yes"
            ;;
        --cleanup-after-use) cleanup_after_use="yes"
            ;;
        --check-fmm) check_fmm="yes"
            ;;
        --fmm-wait-limit)
            shift
            fmm_wait_timer="$1"
            ;;
        --set-securebootlevel) set_secureboot="yes"
            ;;
        --clear-firmware) clear_firmware="yes"
            ;;
        --cloneuser) cloneuser="yes"
            ;;
        --check-power)
            check_power="yes"
            ;;
        --quiet)
            quiet="yes"
            ;;
        --power-wait-limit)
            shift
            power_wait_timer="$1"
            ;;
        --min-battery)
            shift
            min_battery_check="$1"
            ;;
        --min-drive-space)
            shift
            min_drive_space="$1"
            ;;
        --catalogurl)
            shift
            catalogurl="$1"
            ;;
        --catalog)
            shift
            catalog="$1"
            ;;
        --path)
            shift
            installer_directory="$1"
            ;;
        --extras)
            shift
            extras_directory="$1"
            ;;
        --os)
            shift
            prechosen_os="$1"
            ;;
        --newvolumename)
            shift
            newvolumename="$1"
            ;;
        --version)
            shift
            prechosen_version="$1"
            ;;
        --build)
            shift
            prechosen_build="$1"
            ;;
        --workdir)
            shift
            workdir="$1"
            ;;
        --preinstall-command)
            shift
            preinstall_command+=("$1")
            ;;
        --postinstall-command)
            shift
            postinstall_command+=("$1")
            ;;
        --very-insecure-mode) very_insecure_mode="yes"
            ;;
        --credentials)
            shift
            credentials="$1"
            ;;
        --confirmation-icon)
            shift
            custom_icon="yes"
            dialog_confirmation_icon="$1"
            ;;
        --icon-size)
            shift
            dialog_icon_size="$1"
            ;;
        --kc)
            shift
            kc="$1"
            ;;
        --kc-pass)
            shift
            kc_pass="$1"
            ;;
        --kc-service)
            shift
            kc_service="$1"
            ;;
        --language)
            shift
            language_override="$1"
            ;;
        --kc=*)
            kc=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --kc-pass*)
            kc_pass=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --kc-service*)
            kc_service=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --power-wait-limit*)
            power_wait_timer=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --min-battery*)
            min_battery_check=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --min-drive-space*)
            min_drive_space=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --catalogurl*)
            catalogurl=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --catalog*)
            catalog=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --caching-server*)
            caching_server=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --path*)
            installer_directory=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --extras*)
            extras_directory=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --os*)
            prechosen_os=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --user*)
            account_shortname=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --max-password-attempts*)
            new_max_password_attempts=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            if [[ ( $new_max_password_attempts == "infinite" ) || ( $new_max_password_attempts -gt 0 ) ]]; then
                max_password_attempts="$new_max_password_attempts"
            fi
            ;;
        --rebootdelay*)
            rebootdelay=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            if [[ $rebootdelay -gt 300 ]]; then
                rebootdelay=300
            fi
            ;;
        --version*)
            prechosen_version=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --build*)
            prechosen_build=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --workdir*)
            workdir=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --preinstall-command*)
            command=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            preinstall_command+=("$command")
            ;;
        --postinstall-command*)
            command=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            postinstall_command+=("$command")
            ;;
        --credentials*)
            credentials=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        --language*)
            language_override=$(echo "$1" | sed -e 's|^[^=]*=||g' | tr -d '"')
            ;;
        -h|--help) show_help
            ;;
    esac
    shift
done

# create tmp working and log directories if not running as root
if [[ $EUID -ne 0 && "$list" == "yes" ]]; then
    workdir=$(/usr/bin/mktemp -d /var/tmp/erase-install.XXX)
    writelog "[$script_name] Not running as root so will write output and logs to $workdir."
    logdir="$workdir"
fi

# ensure logdir and workdir exist
if [[ ! -d "$workdir" ]]; then
    writelog "[$script_name] Making working directory at $workdir"
    /bin/mkdir -p "$workdir"
fi
if [[ ! -d "$logdir" ]]; then
    writelog "[$script_name] Making log directory at $logdir"
    /bin/mkdir -p "$logdir"
fi

# all output from now on is written also to a log file
LOG_FILE="$logdir/erase-install.log"
log_rotate

# output that the script has started running
echo
writelog "[$script_name] v$version script execution started: $(date)"
echo
writelog "[$script_name] Arguments provided: $all_args"

# announce if the Test Run mode is implemented
if [[ $erase == "yes" || $reinstall == "yes" ]]; then
    if [[ $test_run == "yes" ]]; then
        echo
        writelog "*** TEST-RUN ONLY! ***"
        writelog "* This script will perform all tasks up to the point of erase or reinstall,"
        writelog "* but will not actually erase or reinstall."
        writelog "* Remove the --test-run argument to perform the erase or reinstall."
        writelog "**********************"
        echo
    fi
fi

# set language and localisations
set_localisations

# some options vary based on installer versions
system_version=$( /usr/bin/sw_vers -productVersion )
system_build=$( /usr/bin/sw_vers -buildVersion )

writelog "[$script_name] System version: $system_version (Build: $system_build)"

# check if this is the latest version of erase-install
if [[ "$no_curl" != "yes" ]]; then
    if is-at-least "13" "$system_version"; then 
        latest_erase_install_vers=$(/usr/bin/curl https://api.github.com/repos/grahampugh/erase-install/releases/latest 2>/dev/null | plutil -extract name raw -- -)
        if ! is-at-least "$latest_erase_install_vers" "$version" ; then
            writelog "[$script_name] A newer version of this script is available ($latest_erase_install_vers). Visit https://github.com/grahampugh/erase-install/releases/tag/v$latest_erase_install_vers to obtain the latest version."
        fi
    fi
fi

# bail if system is older than macOS 10.15
if ! is-at-least "10.15" "$system_version"; then 
    writelog "[$script_name] This script requires macOS 10.15 or newer. Please use version 27.x of erase-install.sh on older systems."
    echo
    exit 1
fi

if [[ ! $silent ]]; then
    # bail if system is older than macOS 11 and --silent mode is not selected
    if ! is-at-least "11" "$system_version"; then 
        writelog "[$script_name] This script requires macOS 11 or newer in interactive mode. Please use version 27.3 of erase-install.sh on older systems."
        echo
        exit 1
    fi
    # get dialog app if not silent mode
    check_for_swiftdialog_app
fi

# account for when people mistakenly put a version string instead of a major OS
if [[ "$prechosen_os" ]]; then
    prechosen_os_check=$(cut -d. -f1 <<< "$prechosen_os")
    if [[ $prechosen_os_check = 10 ]]; then
        prechosen_os=$(cut -d. -f1,2 <<< "$prechosen_os")
    else
        prechosen_os=$(cut -d. -f1 <<< "$prechosen_os")
    fi
fi

# set prechosen_os to sameos if selected
if [[ "$sameos" ]]; then
    system_os=$(cut -d. -f 1 <<< "$system_version")
    if [[ $system_os -eq 10 ]]; then
        system_version_major=$(cut -d. -f1,2 <<< "$system_version")
    else
        system_version_major=$(cut -d. -f1 <<< "$system_version")
    fi
    prechosen_os="$system_version_major"
fi

# exit out or correct for incompatible options
if [[ $erase == "yes" && $reinstall == "yes" ]]; then
    writelog "[$script_name] ERROR: Choose either --erase or --reinstall options, but not both!"
    exit 1
elif [[ ($prechosen_os && $prechosen_version) || ($prechosen_os && $prechosen_build) || ($prechosen_version && $prechosen_build) || ($sameos && $prechosen_version) || ($sameos && $prechosen_build) ]]; then
    writelog "[$script_name] ERROR: Choose a maximum of one of the --os, --version, --build, or --sameos options at the same time!"
    exit 1
elif [[ ($overwrite == "yes" && $update_installer == "yes") || ($replace_invalid_installer == "yes" && $overwrite == "yes") || ($replace_invalid_installer == "yes" && $update_installer == "yes") ]]; then
    writelog "[$script_name] ERROR: Choose a maximum of one of the --overwrite, --update, or --replace-invalid options at the same time!"
    exit 1
fi

# different dialog icon for OS older than macOS 13
if ! is-at-least "13" "$system_version"; then 
    dialog_confirmation_icon="/System/Applications/System Preferences.app"
fi

# /Applications is the only path for fetch-full-installer
if [[ $ffi ]]; then
    installer_directory="/Applications"
    if [[ $list == "yes" ]]; then
        list_installers="yes"
    fi
fi

# ensure installer_directory (--path) exists
if [[ ! -d "$installer_directory" ]]; then
    writelog "[$script_name] Making installer directory at $installer_directory"
    /bin/mkdir -p "$installer_directory"
fi

# if getting a list from softwareupdate then we don't need to make any OS checks
if [[ $list == "yes" && ! $ffi ]]; then
    get_mist_list
    echo
    exit
elif [[ $list_installers ]]; then
    if [[ -f "$workdir/ffi-list-full-installers.txt" ]]; then 
        rm "$workdir/ffi-list-full-installers.txt"
    fi
    run_list_full_installers
    /bin/cat "$workdir/ffi-list-full-installers.txt"
    echo
    exit
fi

# everything after this point requires running as root, so stop here if not doing so
if [[ $EUID -ne 0 ]]; then
    writelog "[$script_name] Not running as root so cannot continue."
    exit
fi

# ensure computer does not go to sleep while running this script
writelog "[$script_name] Caffeinating this script (pid=$$)"
/usr/bin/caffeinate -dimsu -w $$ &

# place any extra packages that should be installed as part of the erase-install into this folder. The script will find them and install.
# https://derflounder.wordpress.com/2017/09/26/using-the-macos-high-sierra-os-installers-startosinstall-tool-to-install-additional-packages-as-post-upgrade-tasks/
extras_directory="$workdir/extras"

# set dynamic dialog titles
if [[ $erase == "yes" ]]; then
    dialog_window_title="${(P)dialog_erase_title}"
else
    dialog_window_title="${(P)dialog_reinstall_title}"
fi

if [[ $erase == "yes" || $reinstall == "yes" ]]; then
    # check for drive space if invoking erase or reinstall options
    check_free_space

    # check for user activity - will quit here if a meeting is open
    if [[ $check_for_activity == "yes" ]]; then
        check_for_presentation_activity
    fi
fi

# Look for the installer
writelog "[$script_name] Looking for existing installer app or pkg"
find_existing_installer

# Work through various options to decide whether to replace an existing installer
do_overwrite_existing_installer=0

if [[ $overwrite == "yes" && (-d "$working_macos_app" || ($pkg_installer && -f "$working_installer_pkg")) && ! $list ]]; then
    # --overwrite option
    do_overwrite_existing_installer=1
fi

if [[ "$prechosen_build" ]]; then
    # automatically replace a cached installer if it does not match the requested build
    writelog "[$script_name] Checking if the cached installer matches requested build..."
    if [[ "$installer_build" != "$prechosen_build" ]]; then
        writelog "[$script_name] Existing installer build $prechosen_build does not match requested build $prechosen_build."
        do_overwrite_existing_installer=1
    else
        writelog "[$script_name] Existing installer matches requested build."
    fi
fi

if [[ "$prechosen_os" ]]; then
    # check if the cached installer matches the requested OS
    # first, get the OS of the existing installer app or pkg
    if [[ "$installer_build" ]]; then
        installer_darwin_version=${installer_build:0:2}
    elif [[ "$installer_pkg_build" ]]; then
        installer_darwin_version=${installer_pkg_build:0:2}
    fi
    prechosen_darwin_version=$(get_darwin_from_os_version "$prechosen_os")
    if [[ $installer_darwin_version && ($installer_darwin_version -ne $prechosen_darwin_version) ]]; then
        writelog "[$script_name] Existing installer OS version does not match requested OS ($prechosen_os)."
        do_overwrite_existing_installer=1
    fi
fi

if [[ $update_installer == "yes" ]]; then
    # --update option: checks for a newer installer. This operates within the confines of the --sameos, --os, --version and --beta options if present
    if [[ -d "$working_macos_app" || -f "$working_installer_pkg" ]]; then
        writelog "[$script_name] Checking for newer installer"
        check_newer_available
        if [[ $newer_build_found == "yes" ]]; then
            writelog "[$script_name] Newer installer found."
            do_overwrite_existing_installer=1
        fi
    fi
fi

if [[ $invalid_installer_found == "yes" ]]; then 
    # --replace-invalid option: replace an existing installer if it is invalid
    if [[ -d "$working_macos_app" && $replace_invalid_installer == "yes" ]]; then
        do_overwrite_existing_installer=1
    elif [[ -f "$working_installer_pkg" && $replace_invalid_installer == "yes" ]]; then
        do_overwrite_existing_installer=1
    elif [[ ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]]; then
        writelog "[$script_name] ERROR: Invalid installer is present. Run with --overwrite, --update or --replace-invalid option to ensure that a valid installer is obtained."
        # kill caffeinate
        kill_process "caffeinate"
        exit 1
    elif [[ $skip_validation != "yes" ]]; then
        writelog "[$script_name] ERROR: Invalid installer is present. Run with --overwrite, --update or --replace-invalid option to ensure that a valid installer is obtained."
    else
        writelog "[$script_name] ERROR: Invalid installer is present. --skip-validation was set so we will continue, but failure is highly likely!"
    fi
fi

# now go ahead and remove the existing installer if any conditions were met to do so
if [[ $do_overwrite_existing_installer == 1 ]]; then
    overwrite_existing_installer
fi

# Silicon Macs require a username and password to run startosinstall
# We therefore need credentials to proceed, if we are going to erase or reinstall
# This goes before the download so users aren't waiting for the prompt for username
# Check for Apple Silicon using sysctl, because arch will not report arm64 if running under Rosetta.
[[ $(/usr/sbin/sysctl -q -n "hw.optional.arm64") -eq 1 ]] && arch="arm64" || arch=$(/usr/bin/arch)
writelog "[$script_name] Running on architecture $arch"
if [[ "$arch" == "arm64" && ($erase == "yes" || $reinstall == "yes") ]]; then
    get_user_details
fi

# check for Find My
[[ "$check_fmm" == "yes"  && ($erase == "yes") ]] && check_fmm

# check for power
[[ "$check_power" == "yes"  && ($erase == "yes" || $reinstall == "yes") ]] && check_power_status

if [[ ! -d "$working_macos_app" && ! -f "$working_installer_pkg" ]]; then
    if [[ ! $silent ]]; then
        # if erasing or reinstalling, open a dialog to state that the download is taking place.
        if [[ $erase == "yes" || $reinstall == "yes" || ($dl_dialog == "yes" && $check_for_activity != "yes") ]]; then
            # if no_fs is set, show a utility window instead of the full screen display (for test purposes)
            if [[ $fs == "yes" ]]; then
                window_type="fullscreen"
                iconsize=200
            else
                window_type="utility"
                iconsize=$dialog_icon_size
            fi
            # set the dialog command arguments
            get_default_dialog_args "$window_type"
            dialog_args=("${default_dialog_args[@]}")
            dialog_args+=(
                "--title"
                "${(P)dialog_dl_title}"
                "--icon"
                "${dialog_confirmation_icon}"
                "--overlayicon"
                "SF=arrow.down"
                "--iconsize"
                "$iconsize"
                "--message"
                "${(P)dialog_dl_desc}"
                "--progress"
                "100"
            )
            # run the dialog command
            "$dialog_bin" "${dialog_args[@]}" 2>/dev/null & sleep 0.1
        fi

        if [[ $ffi ]]; then
            dialog_progress fetch-full-installer >/dev/null 2>&1 &
        else
            dialog_progress mist >/dev/null 2>&1 &
        fi
    fi
    # now run mist or softwareupdate to download the installer, showing progress
    if [[ $ffi ]]; then
        run_fetch_full_installer
    else
        run_mist
    fi
fi

if [[ -d "$working_macos_app" ]]; then
    writelog "[$script_name] Installer is at: $working_macos_app"
fi

# Move to $installer_directory if move_to_applications_folder flag is included
# Not relevant for fetch_full_installer option
if [[ $move == "yes" && ("$cached_installer_pkg" || "$cached_installer_app" ) ]]; then
    writelog "[$script_name] Invoking --move option"
    echo "progresstext: Moving installer to Applications folder" >> "$dialog_log"
    if [[ -f "$working_installer_pkg" ]]; then
        unpack_pkg_to_applications_folder
    else
        move_to_applications_folder
    fi
fi

if [[ $erase != "yes" && $reinstall != "yes" ]]; then
    if [[ ! $silent ]]; then
        # quit dialog when the download is complete
        writelog "[$script_name] Sending quit message to dialog log ($dialog_log)"
        echo "quit:" >> "$dialog_log" & sleep 0.1
    fi

    # Clear the working directory
    writelog "[$script_name] Cleaning working directory '$workdir/content'"
    rm -rf "$workdir/content"

    # kill caffeinate
    kill_process "caffeinate"
    echo
    exit
fi

# re-check if there is enough space after a possible installer download
check_free_space

# -----------------------------------------------------------------------------
# Steps beyond here are to run startosinstall
# -----------------------------------------------------------------------------

echo
# if we still have a packege we need to move it before we can install it
if [[ -f "$working_installer_pkg" ]]; then
    unpack_pkg_to_applications_folder
fi

# now look for an installer app
if [[ ! -d "$working_macos_app" ]]; then
    writelog "[$script_name] ERROR: Can't find the installer! "
    # kill caffeinate
    kill_process "caffeinate"
    exit 1
fi

# warnings
if [[ $erase == "yes" ]]; then 
    writelog "[$script_name] WARNING! Running $working_macos_app with eraseinstall option"
elif [[ $reinstall == "yes" ]]; then 
    writelog "[$script_name] WARNING! Running $working_macos_app with reinstall option"
fi
echo

if [[ ! $silent ]]; then
    # quit dialog when the download is complete
    writelog "[$script_name] Sending quit message to dialog log ($dialog_log)"
    echo "quit:" >> "$dialog_log" & sleep 0.1
fi

# if configured to do so, display a confirmation window to the user
if [[ $confirm == "yes" && ! $silent ]]; then
    confirm
fi

# set eraseinstall argument for erase option
install_args=()
if [[ $erase == "yes" ]]; then
    install_args+=("--eraseinstall")
fi

# reinstall option: determine SIP status, as the volume name is required in the startosinstall command if SIP is disabled
if [[ $reinstall == "yes" ]]; then
    if /usr/bin/csrutil status | sed -n 1p | grep -q 'disabled'; then
        volname=$(diskutil info -plist / | grep -A1 "VolumeName" | tail -n 1 | awk -F '<string>|</string>' '{ print $2; exit; }')
        install_args+=("--volume")
        install_args+=("/Volumes/$volname")
    fi
fi

# check for packages then add install_package_list to end of command line (empty if no packages found)
find_extra_packages

# some cli options vary based on installer versions
installer_build=$( /usr/bin/defaults read "$working_macos_app/Contents/Info.plist" DTSDKBuild )
installer_darwin_version=${installer_build:0:2}
# add --preservecontainer to the install arguments if specified (for macOS 10.14 (Darwin 18) and above)
if [[ $preservecontainer == "yes" ]]; then
    install_args+=("--preservecontainer")
fi

# macOS 11 (Darwin 20) and above requires the --allowremoval option
if [[ $installer_darwin_version -ge 20 ]]; then
    install_args+=("--allowremoval")
fi

# macOS 10.15 (Darwin 19) and above can use the --rebootdelay option (reinstall option only)
if [[ "$rebootdelay" -gt 0 && "$reinstall" == "yes" ]]; then
    install_args+=("--rebootdelay")
    install_args+=("$rebootdelay")
else
    # cancel rebootdelay for older systems as we don't support it
    rebootdelay=0
fi

# macOS 10.15 (Darwin 19) and above requires the --forcequitapps options
install_args+=("--forcequitapps")

# pass new volume name if specified
if [[ $erase == "yes" && $newvolumename ]]; then
    install_args+=("--newvolumename")
    install_args+=("$newvolumename")
fi

# add cloneuser key if specified
if [[ $erase == "yes" && $cloneuser ]]; then
    install_args+=("--cloneuser")
fi

# icon for dialogs
# macos_installer_icon="$working_macos_app/Contents/Resources/InstallAssistant.icns"
macos_app_name=$(basename "$working_macos_app" | cut -d. -f1)

# look for the image in the workdir
icon_path="$workdir/icons/$macos_app_name.png"
if ! file -b "$icon_path" | grep "PNG image data" > /dev/null; then
    if [[ ! $no_curl == "yes" ]]; then
        # ensure the icons directory exists
        /bin/mkdir -p "$workdir/icons"
        # download the image from github
        macos_installer_icon_url="https://github.com/grahampugh/erase-install/blob/main/icons/$macos_app_name.png?raw=true"
        curl -L "$macos_installer_icon_url" -o "$icon_path"
    fi
fi

# check again whether we have the image now or a confirmation icon set, if not, display a generic image
if file -b "$icon_path" | grep "PNG image data"; then
    dialog_install_icon="$icon_path"
elif [[ "$custom_icon" == "yes" ]]; then
    dialog_install_icon="$dialog_confirmation_icon"
else
    dialog_install_icon="warning"
fi

# window type for erase and reinstall dialogs
if [[ $fs == "yes" || ($erase == "yes" && $no_fs != "yes") || ($reinstall == "yes" && $no_fs != "yes" && $rebootdelay -lt 10) ]]; then
    window_type="fullscreen"
    iconsize=200
else
    window_type="utility"
    iconsize=$dialog_icon_size
fi

# dialogs for erase
if [[ $erase == "yes" && ! $silent ]]; then
    # set the dialog command arguments
    get_default_dialog_args "$window_type"
    dialog_args=("${default_dialog_args[@]}")
    dialog_args+=(
        "--title"
        "${(P)dialog_erase_title}"
        "--icon"
        "${dialog_install_icon}"
        "--message"
        "${(P)dialog_erase_desc}"
        "--progress"
        "100"
    )
    # run the dialog command
    "$dialog_bin" "${dialog_args[@]}" 2>/dev/null & sleep 0.1

    dialog_progress startosinstall >/dev/null 2>&1 &

# dialogs for reinstallation
elif [[ $reinstall == "yes" && ! $silent ]]; then
    # set the dialog command arguments
    get_default_dialog_args "$window_type"
    dialog_args=("${default_dialog_args[@]}")
    dialog_args+=(
        "--title"
        "${(P)dialog_reinstall_title}"
        "--icon"
        "${dialog_install_icon}"
        "--message"
        "${(P)dialog_reinstall_desc}"
        "--progress"
        "100"
    )
    # run the dialog command
    "$dialog_bin" "${dialog_args[@]}" 2>/dev/null & sleep 0.1

    dialog_progress startosinstall >/dev/null 2>&1 &
fi

# set launchdaemon to remove $workdir if $cleanup_after_use is set
if [[ $cleanup_after_use != "" && $test_run != "yes" ]]; then
    writelog "[$script_name] Writing LaunchDaemon which will remove $workdir at next boot"
    create_launchdaemon_to_remove_workdir
fi

# run preinstall commands
for command in "${preinstall_command[@]}"; do
    if [[ $command ]]; then
        writelog "[$script_name] Now running preinstall command: $command"
        eval "$command"
    fi
done

# preparation for arm64
if [[ "$arch" == "arm64" ]]; then
    install_args+=("--stdinpass")
    install_args+=("--user")
    install_args+=("$account_shortname")
    if [[ $test_run != "yes" && "$erase" == "yes" ]]; then
        # startosinstall --eraseinstall may fail if a user was converted to admin using the Privileges app
        # this command supposedly fixes this problem (experimental!)
        writelog "[$script_name] updating preboot files (takes a few seconds)..."
        sleep 0.1
        echo "progresstext: Updating preboot files..." >> "$dialog_log"
        if /usr/sbin/diskutil apfs updatepreboot / > /dev/null; then
            writelog "[$script_name] preboot files updated"
        else
            writelog "[$script_name] WARNING! preboot files could not be updated."
        fi

        # if --clear-firmware (thanks @mvught)
        if [[ "$clear_firmware" == "yes" ]]; then
            # note this process can take up to 10 seconds
            writelog "[$script_name] Clearing the firmware settings with the nvram command"
            echo "progresstext: Clearing firmware settings..." >> "$dialog_log"
            if /usr/sbin/nvram -c; then
                writelog "[$script_name] nvram command exited with success"
            else
                writelog "[$script_name] WARNING! nvram command exited with error."
            fi
        fi

        # if --set-securebootlevel (thanks @mvught)
        if [[ "$set_secureboot" == "yes" ]]; then
            # note this process can take up to 10 seconds
            writelog "[$script_name] Setting high secure boot level with bputil command"
            echo "progresstext: Setting high secure boot level..." >> "$dialog_log"
            if /usr/bin/bputil -f -u "$current_user" -p "$account_password"; then
                writelog "[$script_name] bputil command exited with success"
            else
                writelog "[$script_name] WARNING! bputil command exited with error."
            fi
        fi
    fi
fi

# now actually run startosinstall
launch_startosinstall

if [[ "$arch" == "arm64" && $test_run != "yes" ]]; then
    writelog "[$script_name] Sending password to startosinstall"
    /bin/cat >&3 <<< "$account_password"
fi
exec 3>&-

# wait for cat command to quit, but no longer than 1 hour
sleep_time=3600
if [[ $no_timeout == "yes" ]]; then
    sleep_time=86400
fi

(sleep $sleep_time; writelog "[$script_name] Timeout reached for PID $pipePID!"; kill -TERM $pipePID) &
wait $pipePID

# we are not supposed to end up here due to USR1 signalling, so something went wrong.
writelog "[$script_name] Reached end of script unexpectedly. This probably means startosinstall failed to complete within $((sleep_time/60)) minutes."
exit 42
