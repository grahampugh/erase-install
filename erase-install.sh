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
# Version 3.3     13.12.2018      Bug fix for --build option, and for exiting gracefully when nothing is downloaded.
#
# Requirements:
# macOS 10.13.4+ is already installed on the device (for eraseinstall option)
# Device file system is APFS
#
# NOTE: at present this script downloads a forked version of Greg's script so that it can properly automate the download process

# URL for downloading installinstallmacos.py
installinstallmacos_URL="https://raw.githubusercontent.com/grahampugh/macadmin-scripts/master/installinstallmacos.py"

# Directory in which to place the macOS installer
installer_directory="/Applications"

# Temporary working directory
workdir="/Library/Management/erase-install"

# Current logged in user
current_user=$(scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')

# Functions
show_help() {
    echo "
    [erase-install] by @GrahamRPugh

    Usage:
    [sudo] bash erase-install.sh [--samebuild] [--move] [--erase] [--build=XYZ] [--overwrite] [--version=X.Y]

    [no flags]:     Finds latest current production, non-forked version
                    of macOS, downloads it.
    --samebuild:    Finds the version of macOS that matches the
                    existing system version, downloads it.
    --version=X.Y:  Finds a specific inputted version of macOS if available
                    and downloads it if so. Will choose the lowest matching build.
    --build=XYZ:    Finds a specific inputted build of macOS if available
                    and downloads it if so.
    --move:         If not erasing, moves the
                    downloaded macOS installer to /Applications
    --erase:        After download, erases the current system
                    and reinstalls macOS
    --overwrite:    Download macOS installer even if an installer
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
    if [[ -f "$macOSDMG" ]]; then
        echo "   [find_existing_installer] Valid installer found at $macOSDMG."
        hdiutil attach "$macOSDMG"
        installmacOSApp=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    elif [[ -d "$installer_app" ]]; then
        echo "   [find_existing_installer] Installer found at $installer_app."
        # check installer validity
        installer_version=$( /usr/bin/defaults read "$installer_app/Contents/Info.plist" DTPlatformVersion | sed 's|10\.||')
        installed_version=$( /usr/bin/sw_vers | grep ProductVersion | awk '{ print $NF }' | sed 's|10\.||')
        if [[ $installer_version -lt $installed_version ]]; then
            echo "   [find_existing_installer] 10.$installer_version < 10.$installed_version so not valid."
        else
            echo "   [find_existing_installer] 10.$installer_version >= 10.$installed_version so valid."
            installmacOSApp="$installer_app"
            app_is_in_applications_folder="yes"
        fi
    else
        echo "   [find_existing_installer] No valid installer found."
    fi
}

overwrite_existing_installer() {
    echo "   [overwrite_existing_installer] Overwrite option selected. Deleting existing version."
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name *'macOS'* -print -quit )
    if [[ -d "$existingInstaller" ]]; then
        diskutil unmount force "$existingInstaller"
    fi
    rm -f "$macOSDMG"
    rm -rf "$installer_app"
}

move_to_applications_folder() {
    if [[ $app_is_in_applications_folder == "yes" ]]; then
        echo "   [move_to_applications_folder] Valid installer already in /Applications folder"
        return
    fi
    echo "   [move_to_applications_folder] Moving installer to /Applications folder"
    cp -R "$installmacOSApp" /Applications/
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name *'macOS'* -print -quit )
    if [[ -d "$existingInstaller" ]]; then
        diskutil unmount force "$existingInstaller"
    fi
    rm -f "$macOSDMG"
    echo "   [move_to_applications_folder] Installer moved to /Applications folder"
}

run_installinstallmacos() {
    # Download installinstallmacos.py
    if [[ ! -d "$workdir" ]]; then
        echo "   [run_installinstallmacos] Making working directory at $workdir"
        mkdir -p $workdir
    fi
    echo "   [run_installinstallmacos] Downloading installinstallmacos.py to $workdir"
    curl -s $installinstallmacos_URL > "$workdir/installinstallmacos.py"

    # Use installinstallmacos.py to download the desired version of macOS
    installinstallmacos_args=''
    if [[ $prechosen_version ]]; then
        echo "   [run_installinstallmacos] Checking that selected version $prechosen_version is available"
        installinstallmacos_args+="--version=$prechosen_version"
        [[ $erase == "yes" ]] && installinstallmacos_args+=" --validate"

    elif [[ $prechosen_build ]]; then
        echo "   [run_installinstallmacos] Checking that selected build $prechosen_build is available"
        installinstallmacos_args+="--build=$prechosen_build"
        [[ $erase == "yes" ]] && installinstallmacos_args+=" --validate"

    elif [[ $samebuild == "yes" ]]; then
        echo "   [run_installinstallmacos] Checking that current build $installed_build is available"
        installinstallmacos_args+="--current"

    else
        echo "   [run_installinstallmacos] Getting current production version"
        installinstallmacos_args+="--auto"
    fi

    python "$workdir/installinstallmacos.py" --workdir=$workdir --ignore-cache --compress $installinstallmacos_args

    if [[ $? > 0 ]]; then
        echo "   [run_installinstallmacos] Error obtaining valid installer. Cannot continue."
        [[ $jamfPID ]] && kill $jamfPID
        echo
        exit 1
    fi

    # Identify the installer dmg
    macOSDMG=$( find $workdir -maxdepth 1 -name 'Install_macOS*.dmg'  -print -quit )
    if [[ -f "$macOSDMG" ]]; then
        echo "   [run_installinstallmacos] Mounting disk image to identify installer app."
        hdiutil attach "$macOSDMG"
        installmacOSApp=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    else
        echo "   [run_installinstallmacos] No disk image found. I guess nothing got downloaded."
        /usr/bin/pkill jamfHelper
        exit
    fi
}

# Main body

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
echo "   [erase-install] Looking for existing installer"
find_existing_installer

if [[ $overwrite == "yes" && -d "$installmacOSApp" ]]; then
    overwrite_existing_installer
fi

if [[ ! -d "$installmacOSApp" ]]; then
    echo "   [erase-install] Starting download process"
    if [[ -f "$jamfHelper" && $erase == "yes" ]]; then
        user_language=$(su -l "${current_user}" -c "/usr/libexec/PlistBuddy -c 'print AppleLanguages:0' ~/Library/Preferences/.GlobalPreferences.plist")
        if [[ ${user_language} = en* ]]; then
            "$jamfHelper" -windowType hud -windowPosition ul -title "Downloading macOS" -alignHeading center -alignDescription left -description "We need to download the macOS installer to your computer; this will take several minutes." -lockHUD -icon  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns" -iconSize 100 &
        elif [[ ${user_language} = de* ]]; then
            "$jamfHelper" -windowType hud -windowPosition ul -title "Download macOS" -alignHeading center -alignDescription left -description "Der macOS Installer wird heruntergeladen, dies dauert mehrere Minuten." -lockHUD -icon  "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns" -iconSize 100 &
        fi
    fi
    # now run installinstallmacos
    run_installinstallmacos
    # Once finished downloading, kill the jamfHelper
    /usr/bin/pkill jamfHelper
fi

if [[ $erase != "yes" ]]; then
    appName=$( basename "$installmacOSApp" )
    if [[ -d "$installmacOSApp" ]]; then
        echo "   [main] Installer is at: $installmacOSApp"
    fi

    # Move to /Applications if move_to_applications_folder flag is included
    if [[ $move == "yes" ]]; then
        move_to_applications_folder
    fi

    # Unmount the dmg
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name *'macOS'* -print -quit )
    if [[ -d "$existingInstaller" ]]; then
        diskutil unmount force "$existingInstaller"
    fi
    # Clear the working directory
    rm -rf "$workdir/content"
    echo
    exit
fi

# 5. Run the installer
echo
echo "   [main] WARNING! Running $installmacOSApp with eraseinstall option"
echo

if [[ -f "$jamfHelper" && $erase == "yes" ]]; then
    echo "   [erase-install] Opening jamfHelper full screen message"
    user_language=$(su -l "${current_user}" -c "/usr/libexec/PlistBuddy -c 'print AppleLanguages:0' ~/Library/Preferences/.GlobalPreferences.plist")
    if [[ ${user_language} = en* ]]; then
        "$jamfHelper" -windowType fs -title "Erasing macOS" -alignHeading center -heading "Erasing macOS" -alignDescription center -description "This computer is now being erased and is locked until rebuilt" -icon "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/Lock.jpg" &
        jamfPID=$(echo $!)
    elif [[ ${user_language} = de* ]]; then
        "$jamfHelper" -windowType fs -title "macOS Wiederherstellen" -alignHeading center -heading "Erasing macOS" -alignDescription center -description "Der Computer wird jetzt zurückgesetzt und neu gestartet." -icon "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/Lock.jpg" &
        jamfPID=$(echo $!)
    fi
fi

"$installmacOSApp/Contents/Resources/startosinstall" --applicationpath "$installmacOSApp" --eraseinstall --agreetolicense --nointeraction

# Kill Jamf FUD if startosinstall ends before a reboot
[[ $jamfPID ]] && kill $jamfPID
