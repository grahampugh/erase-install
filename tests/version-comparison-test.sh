#!/bin/bash

# test script for validating the version comparison logic in erase-install.sh

check_installer_is_valid() {
    # echo "   [check_installer_is_valid] Checking validity of $installer_app."
    # check installer validity:
    # The Build version in the app Info.plist is often older than the advertised build, so it's not a great validity
    # check if running --erase, where we might be using the same build.
    # The actual build number is found in the SharedSupport.dmg in com_apple_MobileAsset_MacSoftwareUpdate.xml.
    # This may not have always been the case, so we include a fallback to the Info.plist file just in case. 
    # hdiutil attach -quiet -noverify "$installer_app/Contents/SharedSupport/SharedSupport.dmg"
    # build_xml="/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
    # if [[ -f "$build_xml" ]]; then
    #     installer_build=$(/usr/libexec/PlistBuddy -c "Print :Assets:0:Build" "$build_xml")
    # else
    #     installer_build=$( /usr/bin/defaults read "$installer_app/Contents/Info.plist" DTSDKBuild )
    # fi
    # diskutil unmount force "/Volumes/Shared Support"

    # system_build=$( /usr/bin/sw_vers -buildVersion )

    # we need to break the build into component parts to compare versions
    # 1. Darwin version is older in the installer than on the system
    if [[ ${installer_build:0:2} -lt ${system_build:0:2} ]]; then 
        invalid_installer_found="yes"
    # 2. Darwin version matches but build letter (minor version) is older in the installer than on the system
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} < ${system_build:2:1} ]]; then
        invalid_installer_found="yes"
    # 3. Darwin version and build letter (minor version) matches but the first two build version numbers are older in the installer than on the system
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} == "${system_build:2:1}" && ${installer_build:3:2} -lt ${system_build:3:2} ]]; then
        echo "   [check_installer_is_valid] Warning: $installer_build < $system_build - find newer installer if this one fails"
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} == "${system_build:2:1}" && ${installer_build:3:2} -eq ${system_build:3:2} ]]; then
        installer_build_minor=${installer_build:5:2}
        system_build_minor=${system_build:5:2}
        # 4. Darwin version, build letter (minor version) and first two build version numbers match, but the second two build version numbers are older in the installer than on the system
        if [[ ${installer_build_minor//[!0-9]/} -lt ${system_build_minor//[!0-9]/} ]]; then
        echo "   [check_installer_is_valid] Warning: $installer_build < $system_build - find newer installer if this one fails"
        # 5. Darwin version, build letter (minor version) and build version numbers match, but beta release letter is older in the installer than on the system (unlikely to ever happen, but just in case)
        elif [[ ${installer_build_minor//[!0-9]/} -eq ${system_build_minor//[!0-9]/} && ${installer_build_minor//[0-9]/} < ${system_build_minor//[0-9]/} ]]; then
        echo "   [check_installer_is_valid] Warning: $installer_build < $system_build - find newer installer if this one fails"
        fi
    fi

    if [[ "$invalid_installer_found" == "yes" ]]; then
        echo "   [check_installer_is_valid] Installer: $installer_build ; System: $system_build : invalid build."
    else
        echo "   [check_installer_is_valid] Installer: $installer_build ; System: $system_build : valid build."
    fi

    install_macos_app="$installer_app"
}

installer_build=$1
system_build=$2

check_installer_is_valid
