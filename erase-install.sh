#!/bin/bash

# erase-install
# by Graham Pugh.
#
# WARNING. This is a self-destruct script. Do not try it out on your own device!
#
# This script downloads and runs installinstallmacos.py from Greg Neagle,
# which expects you to choose a value corresponding to the version of macOS you wish to download.
# This script automatically fills in that value so that it can be run remotely.
#
# See README.md for details on use.
#
## or just run without an argument to check and download the installer as required and then run it to wipe the drive
#
# Version History
# Version 1.0     29.03.2018      Initial version. Expects a manual choice of installer from installinstallmacos.py
# Version 2.0     09.07.2018      Automatically selects a non-beta installer
# Version 3.0     03.09.2018      Changed and additional options for selecting non-standard builds. See README
# Version 3.1     17.09.2018      Added ability to specify a build in the parameters, and we now clear out the cached content
# Version 3.2     21.09.2018      Added ability to specify a macOS version. And fixed the --overwrite flag.
#
# Requirements:
# macOS 10.13.4+ is already installed on the device
# Device file system is APFS
#
# NOTE: at present this script uses a forked version of Greg's script so that it can properly automate the download process

# URL for downloading installinstallmacos.py
installinstallmacos_URL="https://raw.githubusercontent.com/grahampugh/macadmin-scripts/master/installinstallmacos.py"

# Directory in which to place the macOS installer
installer_directory="/Applications"

# Temporary working directory
workdir="/Library/Management/erase-install"


# Functions
show_help() {
    echo "
    [erase-install] by @GrahamRPugh

    Usage:
    [sudo] bash erase-install.sh [--samebuild] [--move] [--erase]

    [no flags]:   Finds latest current production, non-forked version
                  of macOS, downloads it.
    --samebuild:  Finds the version of macOS that matches the
                  existing system version, downloads it.
    --version:    Finds a specific inputted version of macOS if available
                  and downloads it if so. Will choose the lowest matching build.
    --build=XYZ:  Finds a specific inputted build of macOS if available
                and downloads it if so.
    --move:       If not erasing, moves the
                  downloaded macOS installer to /Applications
    --erase:      After download, erases the current system
                  and reinstalls macOS
    --overwrite:  Download macOS installer even if an installer
                  already exists in /Applications

    Note: If existing installer is found, this script will not check
          to see if it matches the installed system version. It will
          only check whether it is a valid installer. If you need to
          ensure that the currently installed version of macOS is used
          to wipe the device, use the --overwrite parameter.
    "
    exit
}

find_existing_installer() {
    installer_app=$( find "$installer_directory/"*macOS*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    # Search for an existing download
    macOSDMG=$( find $workdir/*.dmg -maxdepth 1 -type f -print -quit 2>/dev/null )

    # First let's see if this script has been run before and left an installer
    if [[ -f "$macOSDMG" && ( $overwrite != "yes" || $1 == "again" ) ]]; then
        echo
        echo "   [find_existing_installer] Installer dmg found at: $macOSDMG"
        echo "   [find_existing_installer] Mounting $macOSDMG"
        hdiutil attach "$macOSDMG"
        installmacOSApp=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    elif [[ -f "$macOSDMG" && $overwrite == "yes" && $1 != "again" ]]; then
        echo
        echo "   [find_existing_installer] Overwrite option selected. Deleting existing version."
        rm -f "$macOSDMG"
    # Next see if there's an already downloaded installer
    elif [[ -d "$installer_app" && ( $overwrite != "yes" || $1 == "again" ) ]]; then
        # make sure it is 10.13.4 or newer so we can use --eraseinstall
        installer_version=$( /usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$installer_app/Contents/Info.plist" 2>/dev/null | cut -c1-3 )
        if [[ $installer_version > 133 ]]; then
            echo
            echo "   [find_existing_installer] Valid installer found."
            app_is_in_applications_folder="yes"
            installmacOSApp="$installer_app"
        else
            echo
            echo "   [find_existing_installer] Installer too old."
            [[ $1 == "again" ]] && exit 1
        fi
    elif [[ -d "$installer_app" && $overwrite == "yes" ]]; then
        echo
        echo "   [find_existing_installer] Valid installer found."
        echo "   [find_existing_installer] Overwrite option selected. Deleting existing version."
        rm -rf $installer_app
    else
        echo
        echo "   [find_existing_installer] No valid installer found."
        # if it's still not there on a second pass then the script must fail
        [[ $1 == "again" ]] && exit 1
    fi
}

move_to_applications_folder() {
    # Search for an existing download
    macOSDMG=$( find $workdir/*.dmg -maxdepth 1 -type f -print -quit 2>/dev/null )
    hdiutil attach "$macOSDMG"
    installmacOSApp=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    cp -R "$installmacOSApp" /Applications/
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name *'macOS'* -print -quit )
    if [[ -d "$existingInstaller" ]]; then
        diskutil unmount force "$existingInstaller"
    fi
    rm -f "$macOSDMG"
    echo
    echo "   [move_to_applications_folder] Installer moved to /Applications folder"
    echo
}

run_installinstallmacos() {
    # Download installinstallmacos.py
    if [[ ! -d "$workdir" ]]; then
        echo
        echo "   [run_installinstallmacos] Making working directory at $workdir"
        echo
        mkdir -p $workdir
    fi

    curl -o $workdir/installinstallmacos.py -s $installinstallmacos_URL

    # 3. Use installinstallmacos.py to download the desired version of macOS

    echo
    if [[ $prechosen_version ]]; then
        echo "   [run_installinstallmacos] Checking that selected version $prechosen_version is available using $workdir/installinstallmacos.py"
    elif [[ $prechosen_build ]]; then
        echo "   [run_installinstallmacos] Checking that selected build $prechosen_build is available using $workdir/installinstallmacos.py"
    elif [[ $samebuild == "yes" ]]; then
        installed_build=$( sw_vers | grep BuildVersion | cut -d$'\t' -f2 )
        echo "   [run_installinstallmacos] Checking that current build $installed_build is available using $workdir/installinstallmacos.py"
    else
        echo "   [run_installinstallmacos] Getting current production version from $workdir/installinstallmacos.py"
    fi
    echo

    # Generate the plist
    python $workdir/installinstallmacos.py --workdir $workdir --list --validate

    # Get the number of entries
    plist_count=$( /usr/libexec/PlistBuddy -c 'Print result:' $workdir/softwareupdate.plist | grep index | wc -l | sed -e 's/^ *//' )
    echo
    echo "   [run_installinstallmacos] $plist_count entries found"
    plist_count=$((plist_count-1))

    for index in $( seq 0 $plist_count ); do
        title=$( /usr/libexec/PlistBuddy -c "Print result:$index:title" $workdir/softwareupdate.plist )
        build_check=$( /usr/libexec/PlistBuddy -c "Print result:$index:build" $workdir/softwareupdate.plist )
        version_check=$( /usr/libexec/PlistBuddy -c "Print result:$index:version" $workdir/softwareupdate.plist )
        if [[ $prechosen_version ]]; then
            if [[ "$version_check" == "$prechosen_version" && $title != *"Beta"* ]]; then
                if [[ $build ]]; then
                    build=$( /usr/bin/python -c 'from distutils.version import LooseVersion; build = "'$build'"; build_check = "'$build_check'"; lowest_build = [build if LooseVersion(build) < LooseVersion(build_check) else build_check]; print lowest_build[0]' )
                else
                    build=$build_check
                fi
                if [[ $build_check == $build ]]; then
                    chosen_title="$title"
                fi
            fi
        elif [[ $prechosen_build ]]; then
            if [[ "$build_check" == $prechosen_build ]]; then
                build=$build_check
                chosen_title="$title"
            fi
        elif [[ $samebuild == "yes" ]]; then
            if [[ "$build_check" == $installed_build ]]; then
                build=$build_check
                chosen_title="$title"
            fi
        elif [[ $title != *"Beta"* ]]; then
            if [[ $build ]]; then
                build=$( /usr/bin/python -c 'from distutils.version import LooseVersion; build = "'$build'"; build_check = "'$build_check'"; lowest_build = [build if LooseVersion(build) < LooseVersion(build_check) else build_check]; print lowest_build[0]' )
            else
                build=$build_check
            fi
            if [[ $build_check == $build ]]; then
                chosen_title="$title"
            fi
        fi
    done

    if [[ ! $build ]]; then
        echo
        echo "   [run_installinstallmacos] No valid build found. Exiting"
        echo
        exit 1
    else
        echo
        echo "   [run_installinstallmacos] Build '$build - $chosen_title' found"
        echo
    fi

    # Now run installinstallmacos.py again specifying the build
    python $workdir/installinstallmacos.py --workdir "$workdir" --build $build --compress

    # Identify the installer dmg
    macOSDMG=$( find $workdir -maxdepth 1 -name 'Install_macOS*.dmg'  -print -quit )
}

# Main body

# Existing partially downloaded content can mess things up, so let's clear this out
rm -rf "$workdir/content/downloads"

# Safety mechanism to prevent unwanted wipe while testing
erase="no"

while test $# -gt 0
do
    case "$1" in
        -e|--erase) erase="yes"
            ;;
        -m|--move) move="yes"
            ;;
        -s|--samebuild) samebuild="yes"
            ;;
        -o|--overwrite) overwrite="yes"
            ;;
        --version*)
            prechosen_version=$(echo $1 | sed -e 's/^[^=]*=//g')
            ;;
        --build*)
            prechosen_build=$(echo $1 | sed -e 's/^[^=]*=//g')
            ;;
        -h|--help) show_help
            ;;
    esac
    shift
done

echo
echo "   [erase-install] Script execution started: $(date)"

# Display full screen message if this screen is running on Jamf Pro
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

# Look for the installer, download it if it is not present
echo
echo "   [erase-install] Looking for existing installer"
find_existing_installer

if [[ ! -d "$installmacOSApp" ]]; then
    echo
    echo "   [erase-install] Installer not found, so starting download process"
    if [[ -f "$jamfHelper" && $erase == "yes" ]]; then
        "$jamfHelper" -windowType hud -windowPosition ul -title "Downloading macOS" -alignHeading center -alignDescription left -description "We need to download the macOS installer to your computer; this will take several minutes." -lockHUD -icon  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns" -iconSize 100 &
        jamfPID=$(echo $!)
    fi
    run_installinstallmacos
    [[ $jamfPID ]] && kill $jamfPID

    # Now look again
    echo
    echo "   [erase-install] Looking for existing installer"
    find_existing_installer again
fi

if [[ $erase != "yes" ]]; then
    appName=$( basename "$installmacOSApp" )
    if [[ -d "$installmacOSApp" ]]; then
        echo
        echo "   [main] Installer is at: $installmacOSApp"
    fi

    # Move to /Applications if move_to_applications_folder flag is included
    if [[ $move == "yes" && $app_is_in_applications_folder != "yes" ]]; then
        echo
        echo "   [main] Moving installer to /Applications folder"
        move_to_applications_folder
    elif [[ $move == "yes" ]]; then
        echo
        echo "   [main] Valid installer already in /Applications folder"
    fi

    # Unmount the dmg
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name *'macOS'* -print -quit )
    if [[ -d "$existingInstaller" ]]; then
        diskutil unmount force "$existingInstaller"
    fi
    # Clear the working directory
    rm -rf "$workdir/content"
    exit
fi

# 5. Run the installer
echo
echo "   [main] WARNING! Running $installmacOSApp with eraseinstall option"
echo

if [[ -f "$jamfHelper" && $erase == "yes" ]]; then
    echo
    echo "   [erase-install] Opening jamfHelper full screen message"
    "$jamfHelper" -windowType fs -title "Erasing macOS" -alignHeading center -heading "Erasing macOS" -alignDescription center -description "This computer is now being erased and is locked until rebuilt" -icon "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/Lock.jpg" &
    jamfPID=$(echo $!)
fi

"$installmacOSApp/Contents/Resources/startosinstall" --applicationpath "$installmacOSApp" --eraseinstall --agreetolicense --nointeraction

# Kill Jamf FUD if startosinstall ends before a reboot
[[ $jamfPID ]] && kill $jamfPID
