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
# 1. Checks whether this script has already been run with the `cache` argument and downloaded an installer dmg to the working directory, and mounts it if so.
# 2. If not, checks whether a valid existing macOS installer (>= 10.13.4) is already present in the `/Applications` folder
# 3. If no installer is present, downloads `installinstallmacos.py` and runs it in order to download a valid installer, which is saved to a dmg in the working directory.
# 4. If run without an argument, runs `startosinstall --eraseinstall` with the relevant options in order to wipe the drive and reinstall macOS.
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

# Directory in which to place the macOS installer
installer_directory="/Applications"

# Temporary working directory
workdir="/Library/Management/erase-install"

macOSDMG=$( find ${workdir}/*.dmg -maxdepth 1 -type f -print -quit 2>/dev/null )

# Functions

find_existing_installer() {
    installer_app=$( find "${installer_directory}/Install macOS"*.app -maxdepth 1 -type d -print -quit 2>/dev/null )

    # First let's see if this script has been run before and left an installer
    if [[ -f "${macOSDMG}" ]]; then
        echo "[ $( date ) ] Installer dmg found at: ${macOSDMG}"
        echo "[ $(date) ] Mounting ${macOSDMG}"
        echo
        hdiutil attach "${macOSDMG}"
        installmacOSApp=$( find '/Volumes/Install macOS'*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    # Next see if there's an already downloaded installer
    elif [[ -d "${installer_app}" ]]; then
        # make sure it is 10.13.4 or newer so we can use --eraseinstall
        installer_version=$( /usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "${installer_app}/Contents/Info.plist" 2>/dev/null | cut -c1-3 )
        if [[ ${installer_version} > 133 ]]; then
            echo "[ $( date ) ] Valid installer found. No need to download."
            installmacOSApp="${installer_app}"
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
            build_check=$( /usr/libexec/PlistBuddy -c "Print result:${index}:build" ${workdir}/softwareupdate.plist )
            if [[ $build ]]; then
                build=$( /usr/bin/python -c 'from distutils.version import LooseVersion; build = "'$build'"; build_check = "'$build_check'"; lowest_build = [build if LooseVersion(build) < LooseVersion(build_check) else build_check]; print lowest_build[0]' )
            else
                build=$build_check
            fi
            if [[ $build_check == $build ]]; then
                chosen_title="${title}"
            fi
        fi
    done

    if [[ ! ${build} ]]; then
        echo "[ $(date) ] No valid build found. Exiting"
        exit 1
    else
        echo "[ $(date) ] Build '$build - $chosen_title' found"
    fi

    echo
    # Now run installinstallmacos.py again specifying the build
    python ${workdir}/installinstallmacos.py --workdir "${workdir}" --build ${build} --compress

    # Identify the installer dmg
    macOSDMG=$( find ${workdir} -maxdepth 1 -name 'Install_macOS*.dmg'  -print -quit )
}

# Main body

[[ $1 == "cache" || $4 == "cache" ]] && cache_only="yes" || cache_only="no"

# Display full screen message if this screen is running on Jamf Pro
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

if [[ -f "${jamfHelper}" && ${cache_only} != "yes" ]]; then
    "${jamfHelper}" -windowType fs -title "Erasing macOS" -alignHeading center -heading "Erasing macOS" -alignDescription center -description "This computer is now being erased and is locked until rebuilt" -icon /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/Lock.jpg &
fi

# Look for the installer, download it if it is not present
find_existing_installer
if [[ ! -d "${installmacOSApp}" ]]; then
    run_installinstallmacos
fi

# Now look again
find_existing_installer
if [[ ! -d "${installmacOSApp}" ]]; then
    echo "[ $(date) ] macOS Installer not found, cannot continue"
    exit 1
fi

if [[ ${cache_only} == "yes" ]]; then
    appName=$( basename "$installmacOSApp" )
    if [[ ! -d "${installmacOSApp}" ]]; then
        echo "[ $(date) ] Installer is at: $installmacOSApp"
    fi

    # Unmount the dmg
    existingInstaller=$( find /Volumes -maxdepth 1 -type d -name 'Install macOS*' -print -quit )
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

# "${installmacOSApp}/Contents/Resources/startosinstall" --applicationpath "${installmacOSApp}" --eraseinstall --agreetolicense --nointeraction
