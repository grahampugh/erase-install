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
# Specifically, this script does the following:
# 1. Checks whether a valid existing macOS installer (>= 10.13.4) is present in the Applications folder
# 2. If no installer is present, downloads installinstallmacos.py and runs it in order to download a valid installer
# 3. If run in `cache` mode, copies the installer to the Applications folder and quits
# 4. If run in normal mode, runs startosinstall --eraseinstall to wipe the drive and reinstall macOS
#
# Options:
# Run the script with the "cache" argument to check and download the installer as required, and copy it to /Applications
# e.g.
# sudo bash erase-install.sh cache
#
# or just run without an argument to check and download the installer as required and then run it to wipe the drive
#
# Version History
# Version 1.0     29.03.2018      Initial version. Expects a manual choice of installer from installinstallmacos.py
# Version 2.0     09.07.2018      Updated version automatically selects a non-beta installer
#
# Requirements:
# macOS 10.13.4+ is already installed on the device
# Device file system is APFS
#
# NOTE: at present this script uses a forked version of Greg's script so that it can properly automate the download process

# URL for downloading installinstallmacos.py
installinstallmacos_URL=https://raw.githubusercontent.com/grahampugh/macadmin-scripts/master/installinstallmacos.py

# The installer_app_name will need to be updated as new versions of macOS are released
installer_app_name="Install macOS High Sierra.app"

# Directory in which to place the macOS installer
installer_directory="/Applications"

# Temporary working directory
workdir="/Library/Management/erase-install"

# Functions

find_existing_installer() {
    # Let's see if there is already a version of macOS High Sierra on this device
    if [[ -d "${installer_directory}/${installer_app_name}" ]]; then
        # make sure it is 10.13.4 or newer so we can use --eraseinstall
        installer_version=$( /usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "${installer_directory}/${installer_app_name}/Contents/Info.plist" | cut -c1-3 )
        if [[ ${installer_version} > 133 ]]; then
            echo "[ $( date ) ] Valid installer found. No need to download."
            installmacOSApp="${installer_directory}/${installer_app_name}"
        else
            echo "[ $( date ) ] Installer too old."
        fi
    else
        echo "[ $( date ) ] No valid installer found."
    fi
}

run_installinstallmacos() {
    # Download installinstallmacos.py
    if [[ ! -d "${workdir}" ]]; then
        echo
        echo "[ $(date) ] Making working directory at ${workdir}"
        echo
        mkdir -p ${workdir}
    fi

    curl -o ${workdir}/installinstallmacos.py -s ${installinstallmacos_URL}

    # 3. Use installinstallmacos.py to download the desired version of macOS

    echo "[ $(date) ] Getting current production version from ${workdir}/installinstallmacos.py"
    echo
    # Generate the plist
    python ${workdir}/installinstallmacos.py --workdir ${workdir} --list
    echo

    # Get the number of entries
    plist_count=$( /usr/libexec/PlistBuddy -c 'Print result:' ${workdir}/softwareupdate.plist | grep index | wc -l | sed -e 's/^ *//' )
    echo "[ $(date) ] $plist_count entries found"
    plist_count=$((plist_count-1))

    for index in $( seq 0 $plist_count ); do
        title=$( /usr/libexec/PlistBuddy -c "Print result:${index}:title" ${workdir}/softwareupdate.plist )
        if [[ ${title} != *"Beta"* ]]; then
            build=$( /usr/libexec/PlistBuddy -c "Print result:${index}:build" ${workdir}/softwareupdate.plist )
        fi
    done

    if [[ ! ${build} ]]; then
        echo "[ $(date) ] No valid build found. Exiting"
        exit 1
    else
        echo "[ $(date) ] Build '$build - $title' found"
    fi

    echo
    # Now run installinstallmacos.py again specifying the build
    python ${workdir}/installinstallmacos.py --workdir "${workdir}" --build ${build}

    # 4. Mount the installer and locate the app name

    macOSSparseImage=$( find ${workdir}/Install_macOS*.sparseimage )

    existingInstaller=$( find /Volumes/Install_macOS* )
    if [[ -d "${existingInstaller}" ]]; then
        disktuil unmount force "${existingInstaller}"
    fi

    echo "[ $(date) ] Mounting ${macOSSparseImage}"
    echo

    hdiutil attach "${macOSSparseImage}"

    installmacOSApp=$( find /Volumes/Install_macOS*/Applications/Install*.app -d -maxdepth 0 )
}

# Main body

# Display full screen message if this screen is running on Jamf Pro
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

if [[ -f "${jamfHelper}" && $1 != "cache" ]]; then
    "${jamfHelper}" -windowType fs -title "Erasing macOS" -alignHeading center -heading "Erasing macOS" -alignDescription center -description "This computer is now being erased and is locked until rebuilt" -icon /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/Lock.jpg &
fi

# Look for the installer, download it if it is not present
find_existing_installer
if [[ ! -d "${installmacOSApp}" ]]; then
    run_installinstallmacos
fi

if [[ ! -d "${installmacOSApp}" ]]; then
    echo "[ $(date) ] macOS Installer not found, cannot continue"
    exit 1
fi

if [[ $1 == "cache" ]]; then
    appName=$( basename "$installmacOSApp" )
    if [[ ! -d "${installer_directory}/${installer_app_name}" ]]; then
        echo "[ $(date) ] Installer saved to: ${installer_directory}/$appName"
        cp -r "${installmacOSApp}" "${installer_directory}/"
    else
        echo "[ $(date) ] Installer already at: $installmacOSApp"
    fi
    # Unmount the sparseimage
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name 'Install_macOS*' -print -quit )
    if [[ -d "${existingInstaller}" ]]; then
        diskutil unmount force "${existingInstaller}"
    fi
    # Clear the working directory
    rm -rf "${workdir}/content"
    exit
fi

# 5. Run the installer
echo "[ $(date) ] WARNING! Running ${installmacOSApp} with eraseinstall option"
echo

"${installmacOSApp}/Contents/Resources/startosinstall" --applicationpath "${installmacOSApp}" --eraseinstall --agreetolicense --nointeraction
