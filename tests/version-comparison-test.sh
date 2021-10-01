#!/bin/bash

#  test script for validating the version comparison logic in erase-install.sh

check_installer_is_valid() {
    # echo "   [check_installer_is_valid] Checking validity of $installer_app."
    # check installer validity:
    # The Build version in the app Info.plist is often older than the advertised build, 
    # so it's not a great check for validity
    # check if running --erase, where we might be using the same build.
    # The actual build number is found in the SharedSupport.dmg in com_apple_MobileAsset_MacSoftwareUpdate.xml (Big Sur and greater).
    # This is new from Big Sur, so we include a fallback to the Info.plist file just in case. 

    # first ensure that some earlier instance is not still mounted as it might interfere with the check
    # [[ -d "/Volumes/Shared Support" ]] && diskutil unmount force "/Volumes/Shared Support"
    # # now attempt to mount
    # if hdiutil attach -quiet -noverify "$installer_app/Contents/SharedSupport/SharedSupport.dmg" ; then
    #     build_xml="/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
    #     if [[ -f "$build_xml" ]]; then
    #         echo "   [check_installer_is_valid] Using Build value from com_apple_MobileAsset_MacSoftwareUpdate.xml"
    #         installer_build=$(/usr/libexec/PlistBuddy -c "Print :Assets:0:Build" "$build_xml")
    #         sleep 1
    #         diskutil unmount force "/Volumes/Shared Support"
    #     fi
    # else
    #     # if that fails, fallback to the method for 10.15 or less, which is less accurate
    #     echo "   [check_installer_is_valid] Using DTSDKBuild value from Info.plist"
    #     installer_build=$( /usr/bin/defaults read "$installer_app/Contents/Info.plist" DTSDKBuild )
    # fi

    # system_build=$( /usr/bin/sw_vers -buildVersion )

    # we need to break the build into component parts to fully compare versions
    installer_darwin_version=${installer_build:0:2}
    system_darwin_version=${system_build:0:2}
    installer_build_letter=${installer_build:2:1}
    system_build_letter=${system_build:2:1}
    installer_build_version=${installer_build:3}
    system_build_version=${system_build:3}

    # 1. Darwin version is older in the installer than on the system
    if [[ $installer_darwin_version -lt $system_darwin_version ]]; then 
        invalid_installer_found="yes"
    # 2. Darwin version matches but build letter (minor version) is older in the installer than on the system
    elif [[ $installer_darwin_version -eq $system_darwin_version && $installer_build_letter < $system_build_letter ]]; then
        invalid_installer_found="yes"
    # 3. Darwin version and build letter (minor version) matches but the first three build version numbers are older in the installer than on the system
    elif [[ $installer_darwin_version -eq $system_darwin_version && $installer_build_letter == "$system_build_letter" && ${installer_build_version:3} -lt ${system_build_version:3} ]]; then
        warning_issued="yes"
    elif [[ $installer_darwin_version -eq $system_darwin_version && $installer_build_letter == "$system_build_letter" && ${installer_build_version:3} -eq ${system_build_version:3} ]]; then
        installer_build_minor=${installer_build:5:2}
        system_build_minor=${system_build:5:2}
        # 4. Darwin version, build letter (minor version) and first three build version numbers match, but the fourth build version number is older in the installer than on the system
        if [[ ${installer_build_minor//[!0-9]/} -lt ${system_build_minor//[!0-9]/} ]]; then
        warning_issued="yes"
        # 5. Darwin version, build letter (minor version) and build version numbers match, but beta release letter is older in the installer than on the system (unlikely to ever happen, but just in case)
        elif [[ ${installer_build_minor//[!0-9]/} -eq ${system_build_minor//[!0-9]/} && ${installer_build_minor//[0-9]/} < ${system_build_minor//[0-9]/} ]]; then
        warning_issued="yes"
        fi
    fi

    if [[ "$invalid_installer_found" == "yes" ]]; then
        echo "   [check_installer_is_valid] Installer: $installer_build < System: $system_build : invalid build."
    elif [[ "$warning_issued" == "yes" ]]; then
        echo "   [check_installer_is_valid] Installer: $installer_build < System: $system_build : build might work but if it fails, please obtain a newer installer."
    else
        echo "   [check_installer_is_valid] Installer: $installer_build > System: $system_build : valid build."
    fi

    install_macos_app="$installer_app"
}

echo "   [check_installer_is_valid] Parameter 1: installer"
echo "   [check_installer_is_valid] Parameter 2: system"

installer_build=$1
system_build=$2

check_installer_is_valid
