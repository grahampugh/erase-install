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
# Requirements:
# macOS 10.13.4+ is already installed on the device (for eraseinstall option)
# Device file system is APFS
#
# NOTE: at present this script downloads a forked version of Greg's script so that it can properly automate the download process

# URL for downloading installinstallmacos.py
installinstallmacos_URL="https://raw.githubusercontent.com/grahampugh/macadmin-scripts/master/installinstallmacos.py"

# Directory in which to place the macOS installer. Overridden with --path
installer_directory="/Applications"

# Temporary working directory
workdir="/Library/Management/erase-install"

# place any extra packages that should be installed as part of the erase-install into this folder. The script will find them and install.
# https://derflounder.wordpress.com/2017/09/26/using-the-macos-high-sierra-os-installers-startosinstall-tool-to-install-additional-packages-as-post-upgrade-tasks/
extras_directory="$workdir/extras"

# Display downloading and erasing messages if this is running on Jamf Pro
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

if [[ -f "$jamfHelper" ]]; then
    # Jamf Helper localizations - download window
    jh_dl_title_en="Downloading macOS"
    jh_dl_desc_en="We need to download the macOS installer to your computer; this will take several minutes."
    jh_dl_title_de="Download macOS"
    jh_dl_desc_de="Der macOS Installer wird heruntergeladen, dies dauert mehrere Minuten."
    # Jamf Helper localizations - erase lockscreen
    jh_erase_title_en="Erasing macOS"
    jh_erase_desc_en="This computer is now being erased and is locked until rebuilt"
    jh_erase_title_de="macOS Wiederherstellen"
    jh_erase_desc_de="Der Computer wird jetzt zurückgesetzt und neu gestartet"
    # Jamf Helper localizations - reinstall lockscreen
    jh_reinstall_title_en="Reinstalling macOS"
    jh_reinstall_desc_en="macOS will be reinstalled on this computer, and is locked until complete"
    jh_reinstall_title_de="macOS Wiederherstellen"
    jh_reinstall_desc_de="macOS wird neu installiert und neu gestartet"

    # Jamf Helper icons for the download and erase windows
    jh_dl_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns"
    jh_erase_icon="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/Lock.jpg"
    jh_reinstall_icon="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/Lock.jpg"

    # Grab currently logged in user to set the language for Jamf Helper messages
    current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
    language=$(/usr/libexec/PlistBuddy -c 'print AppleLanguages:0' "/Users/${current_user}/Library/Preferences/.GlobalPreferences.plist")
    if [[ $language = de* ]]; then
        user_language="de"
    else
        user_language="en"
    fi

    # set localisation variables
    jh_dl_title=jh_dl_title_${user_language}
    jh_dl_desc=jh_dl_desc_${user_language}
    jh_erase_title=jh_erase_title_${user_language}
    jh_erase_desc=jh_erase_desc_${user_language}
    jh_reinstall_title=jh_reinstall_title_${user_language}
    jh_reinstall_desc=jh_reinstall_desc_${user_language}
fi

# Functions
show_help() {
    echo "
    [erase-install] by @GrahamRPugh

    Usage:
    [sudo] ./erase-install.sh [--list] [--samebuild] [--move] [--path=/path/to]
                [--build=XYZ] [--overwrite] [--os=X.Y] [--version=X.Y.Z]
                [--erase] [--reinstall]

    [no flags]        Finds latest current production, non-forked version
                      of macOS, downloads it.
    --seedprogram=... Select a non-standard seed program
    --catalogurl=...  Select a non-standard catalog URL (overrides seedprogram)
    --samebuild       Finds the version of macOS that matches the
                      existing system version, downloads it.
    --os=X.Y          Finds a specific inputted OS version of macOS if available
                      and downloads it if so. Will choose the lowest matching build.
    --version=X.Y.Z   Finds a specific inputted minor version of macOS if available
                      and downloads it if so. Will choose the lowest matching build.
    --build=XYZ       Finds a specific inputted build of macOS if available
                      and downloads it if so.
    --move            If not erasing, moves the
                      downloaded macOS installer to $installer_directory
    --path=/path/to   Overrides the destination of --move to a specified directory
    --extras=/path/to Overrides the path to search for extra packages
    --erase           After download, erases the current system
                      and reinstalls macOS
    --reinstall       After download, reinstalls macOS without erasing the
                      current system
    --overwrite       Download macOS installer even if an installer
                      already exists in $installer_directory
    --list            List available updates only (don't download anything)

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
    macOSSparseImage=$( find $workdir/*.sparseimage -maxdepth 1 -type f -print -quit 2>/dev/null )

    # First let's see if this script has been run before and left an installer
    if [[ -f "$macOSDMG" ]]; then
        echo "   [find_existing_installer] Installer image found at $macOSDMG."
        hdiutil attach "$macOSDMG"
        installmacOSApp=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    elif [[ -f "$macOSSparseImage" ]]; then
        echo "   [find_existing_installer] Installer sparse image found at $macOSSparseImage."
        hdiutil attach "$macOSSparseImage"
        installmacOSApp=$( find '/Volumes/'*macOS*/Applications/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    elif [[ -d "$installer_app" ]]; then
        echo "   [find_existing_installer] Installer found at $installer_app."
        # check installer validity:
        # split the version of the downloaded installer into OS and minor versions
        installer_version=$( /usr/bin/defaults read "$installer_app/Contents/Info.plist" DTPlatformVersion )
        installer_os_version=$( echo "$installer_version" | cut -d '.' -f 2 )
        installer_minor_version=$( /usr/bin/defaults read "$installer_app/Contents/Info.plist" CFBundleShortVersionString | cut -d '.' -f 2 )
        # split the version of the downloaded installer into OS and minor versions
        installed_version=$( /usr/bin/sw_vers | grep ProductVersion | awk '{ print $NF }' )
        installed_os_version=$( echo "$installed_version" | cut -d '.' -f 2 )
        installed_minor_version=$( echo "$installed_version" | cut -d '.' -f 3 )
        if [[ $installer_os_version -lt $installed_os_version ]]; then
            echo "   [find_existing_installer] $installer_version < $installed_version so not valid."
        elif [[ $installer_os_version -eq $installed_os_version ]]; then
            if [[ $installer_minor_version -lt $installed_minor_version ]]; then
                echo "   [find_existing_installer] $installer_version.$installer_minor_version < $installed_version so not valid."
            else
                echo "   [find_existing_installer] $installer_version.$installer_minor_version >= $installed_version so valid."
                installmacOSApp="$installer_app"
                app_is_in_applications_folder="yes"
            fi
        else
            echo "   [find_existing_installer] $installer_version.$installer_minor_version >= $installed_version so valid."
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
    rm -f "$macOSDMG" "$macOSSparseImage"
    rm -rf "$installer_app"
}

move_to_applications_folder() {
    if [[ $app_is_in_applications_folder == "yes" ]]; then
        echo "   [move_to_applications_folder] Valid installer already in $installer_directory folder"
        return
    fi
    echo "   [move_to_applications_folder] Moving installer to $installer_directory folder"
    cp -R "$installmacOSApp" $installer_directory/
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name *'macOS'* -print -quit )
    if [[ -d "$existingInstaller" ]]; then
        diskutil unmount force "$existingInstaller"
    fi
    rm -f "$macOSDMG" "$macOSSparseImage"
    echo "   [move_to_applications_folder] Installer moved to $installer_directory folder"
}

find_extra_packages() {
    # set install_package_list to blank.
    install_package_list=()
    for file in "$extras_directory"/*.pkg; do
        if [[ $file != *"/*.pkg" ]]; then
            echo "   [find_extra_installers] Additional package to install: $file"
            install_package_list+=("--installpackage")
            install_package_list+=("$file")
        fi
    done
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

    if [[ $list == "yes" ]]; then
        echo "   [run_installinstallmacos] List only mode chosen"
        installinstallmacos_args+="--list "
    else
        installinstallmacos_args+="--workdir=$workdir"
        installinstallmacos_args+=" --ignore-cache --raw "
    fi

    if [[ $catalogurl ]]; then
        echo "   [run_installinstallmacos] Non-standard catalog URL selected"
        installinstallmacos_args+="--catalogurl $catalogurl "
    elif [[ $seedprogram ]]; then
        echo "   [run_installinstallmacos] Non-standard seedprogram selected"
        installinstallmacos_args+="--seedprogram $seedprogram "
    fi

    if [[ $prechosen_os ]]; then
        echo "   [run_installinstallmacos] Checking that selected OS $prechosen_os is available"
        installinstallmacos_args+="--os=$prechosen_os"
        [[ $erase == "yes" || $reinstall == "yes" ]] && installinstallmacos_args+=" --validate"

    elif [[ $prechosen_version ]]; then
        echo "   [run_installinstallmacos] Checking that selected version $prechosen_version is available"
        installinstallmacos_args+="--version=$prechosen_version"
        [[ $erase == "yes" || $reinstall == "yes" ]] && installinstallmacos_args+=" --validate"

    elif [[ $prechosen_build ]]; then
        echo "   [run_installinstallmacos] Checking that selected build $prechosen_build is available"
        installinstallmacos_args+="--build=$prechosen_build"
        [[ $erase == "yes" || $reinstall == "yes" ]] && installinstallmacos_args+=" --validate"

    elif [[ $samebuild == "yes" ]]; then
        echo "   [run_installinstallmacos] Checking that current build $installed_build is available"
        installinstallmacos_args+="--current"

    elif [[ ! $list ]]; then
        #statements
        echo "   [run_installinstallmacos] Getting current production version"
        installinstallmacos_args+="--auto"
    fi

    python "$workdir/installinstallmacos.py" $installinstallmacos_args

    if [[ $list == "yes" ]]; then
        exit 0
    fi

    if [[ $? > 0 ]]; then
        echo "   [run_installinstallmacos] Error obtaining valid installer. Cannot continue."
        [[ $jamfPID ]] && kill $jamfPID
        echo
        exit 1
    fi

    # Identify the installer dmg
    macOSDMG=$( find $workdir -maxdepth 1 -name 'Install_macOS*.dmg' -type f -print -quit )
    macOSSparseImage=$( find $workdir -maxdepth 1 -name 'Install_macOS*.sparseimage' -type f -print -quit )
    if [[ -f "$macOSDMG" ]]; then
        echo "   [run_installinstallmacos] Mounting disk image to identify installer app."
        hdiutil attach "$macOSDMG"
        installmacOSApp=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    elif [[ -f "$macOSSparseImage" ]]; then
        echo "   [run_installinstallmacos] Mounting sparse disk image to identify installer app."
        hdiutil attach "$macOSSparseImage"
        installmacOSApp=$( find '/Volumes/'*macOS*/Applications/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    else
        echo "   [run_installinstallmacos] No disk image found. I guess nothing got downloaded."
        /usr/bin/pkill jamfHelper
        exit
    fi
}

# Main body

# Safety mechanism to prevent unwanted wipe while testing
erase="no"
reinstall="no"

while test $# -gt 0
do
    case "$1" in
        -l|--list) list="yes"
            ;;
        -e|--erase) erase="yes"
            ;;
        -r|--reinstall) reinstall="yes"
            ;;
        -m|--move) move="yes"
            ;;
        -s|--samebuild) samebuild="yes"
            ;;
        -o|--overwrite) overwrite="yes"
            ;;
        --seedprogram*)
            seedprogram=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        --catalogurl*)
            catalogurl=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        --path*)
            installer_directory=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        --extras*)
            extras_directory=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        --os*)
            prechosen_os=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        --version*)
            prechosen_version=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        --build*)
            prechosen_build=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        --workdir*)
            workdir=$(echo $1 | sed -e 's|^[^=]*=||g')
            ;;
        -h|--help) show_help
            ;;
    esac
    shift
done

echo
echo "   [erase-install] Script execution started: $(date)"

# ensure installer_directory exists
/bin/mkdir -p "$installer_directory"

# Look for the installer, download it if it is not present
echo "   [erase-install] Looking for existing installer"
find_existing_installer

if [[ $overwrite == "yes" && -d "$installmacOSApp" && ! $list ]]; then
    overwrite_existing_installer
fi

if [[ ! -d "$installmacOSApp" || $list ]]; then
    echo "   [erase-install] Starting download process"
    # if using Jamf and due to erase, open a helper hud to state that
    # the download is taking place.
    if [[ -f "$jamfHelper" && ($erase == "yes" || $reinstall == "yes") ]]; then
        echo "   [erase-install] Opening jamfHelper download message (language=$user_language)"
        "$jamfHelper" -windowType hud -windowPosition ul -title "${!jh_dl_title}" -alignHeading center -alignDescription left -description "${!jh_dl_desc}" -lockHUD -icon  "$jh_dl_icon" -iconSize 100 &
    fi
    # now run installinstallmacos
    run_installinstallmacos
    # Once finished downloading, kill the jamfHelper
    /usr/bin/pkill jamfHelper
fi

if [[ $erase != "yes" && $reinstall != "yes" ]]; then
    appName=$( basename "$installmacOSApp" )
    if [[ -d "$installmacOSApp" ]]; then
        echo "   [erase-install] Installer is at: $installmacOSApp"
    fi

    # Move to $installer_directory if move_to_applications_folder flag is included
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

# Run the installer
echo
[[ $erase == "yes" ]] && echo "   [erase-install] WARNING! Running $installmacOSApp with eraseinstall option"
[[ $reinstall == "yes" ]] && echo "   [erase-install] WARNING! Running $installmacOSApp with reinstall option"
echo

if [[ -f "$jamfHelper" && $erase == "yes" ]]; then
    echo "   [erase-install] Opening jamfHelper full screen message (language=$user_language)"
    "$jamfHelper" -windowType fs -title "${!jh_erase_title}" -alignHeading center -heading "${!jh_erase_title}" -alignDescription center -description "${!jh_erase_desc}" -icon "$jh_erase_icon" &
    jamfPID=$(echo $!)
elif [[ $reinstall == "yes" ]]; then
    echo "   [erase-install] Opening jamfHelper full screen message (language=$user_language)"
    "$jamfHelper" -windowType fs -title "${!jh_reinstall_title}" -alignHeading center -heading "${!jh_reinstall_title}" -alignDescription center -description "${!jh_reinstall_desc}" -icon "$jh_reinstall_icon" &
    jamfPID=$(echo $!)
    #statements
fi

# check for packages then add install_package_list to end of command line (empty if no packages found)
find_extra_packages

# vary command line based on installer versions
installer_version=$( /usr/bin/defaults read "$installmacOSApp/Contents/Info.plist" DTPlatformVersion )
installer_os_version=$( echo "$installer_version" | sed 's|^10\.||' | sed 's|\..*||' )

if [ "$installer_os_version" == "13" ]; then
    [[ $erase == "yes" ]] && installflag="--eraseinstall"
    if [[ $reinstall == "yes" ]]; then
        volname=$(diskutil info / | grep "Volume Name" | awk '{ print $(NF-1),$NF; }')
        volpath="/Volumes/$volname"
        installflag="--volume \"$volpath\""
    fi
    "$installmacOSApp/Contents/Resources/startosinstall" $installflag --applicationpath "$installmacOSApp"  --agreetolicense --nointeraction "${install_package_list[@]}"
else
    "$installmacOSApp/Contents/Resources/startosinstall" "$installflag" --agreetolicense --nointeraction "${install_package_list[@]}"
fi

# Kill Jamf FUD if startosinstall ends before a reboot
[[ $jamfPID ]] && kill $jamfPID
