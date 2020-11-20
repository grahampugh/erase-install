#!/bin/bash

check_installer_is_valid() {
    echo "   [check_installer_is_valid] Checking validity of $installer_app."
    # check installer validity:

    # we need to break the build into component parts to compare versions
    # 1. Darwin version is older in the installer than on the system
    if [[ ${installer_build:0:2} -lt ${system_build:0:2} ]]; then 
        invalid_installer_found="yes"
    # 2. Darwin version matches but build letter (minor version) is older in the installer than on the system
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} < ${system_build:2:1} ]]; then
        invalid_installer_found="yes"
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} == ${system_build:2:1} ]]; then
        installer_build_minor=${installer_build:3:5}
        system_build_minor=${system_build:3:5}
        # 3. Darwin version and build letter (minor version) matches but build version numbers are older in the installer than on the system
       if [[ ${installer_build_minor//[!0-9]/} -lt ${system_build_minor//[!0-9]/} ]]; then
            invalid_installer_found="yes"
        # 4. Darwin version, build letter (minor version) and build version numbers matches but beta release letter is older in the installer than on the system (unlikely to ever happen, but just in case)
        elif [[ ${installer_build_minor//[!0-9]/} -eq ${system_build_minor//[!0-9]/} && ${installer_build_minor//[0-9]/} < ${system_build_minor//[0-9]/} ]]; then
            invalid_installer_found="yes"
        fi
    fi

    if [[ "$invalid_installer_found" == "yes" ]]; then
        echo "   [check_installer_is_valid] $installer_build < $system_build so not valid."
    else
        echo "   [check_installer_is_valid] $installer_build >= $system_build so valid."
    fi
}

installer_build=$1
system_build=$2

check_installer_is_valid
