#!/bin/bash

#  test script for validating the version comparison logic in erase-install.sh

check_newer_available() {
    # Download installinstallmacos.py
    # get_installinstallmacos
    # run installinstallmacos.py with list and then interrogate the plist
    # [[ ! -f "$python_path" ]] && python_path=$(which python)
    # "$python_path" "$workdir/installinstallmacos.py" --list --workdir="$workdir" > /dev/null
    # i=0
    newer_build_found="no"
    # while available_build=$( /usr/libexec/PlistBuddy -c "Print :result:$i:build" "$workdir/softwareupdate.plist" 2>/dev/null); do
        available_build_darwin=${available_build:0:2}
        installer_build_darwin=${installer_build:0:2}
        available_build_letter=${available_build:2:1}
        installer_build_letter=${installer_build:2:1}
        available_build_minor=${available_build:3}
        installer_build_minor=${installer_build:3}
        available_build_minor_no=${available_build_minor//[!0-9]/}
        installer_build_minor_no=${installer_build_minor//[!0-9]/}
        available_build_minor_beta=${available_build_minor//[0-9]/}
        installer_build_minor_beta=${installer_build_minor//[0-9]/}
        echo "   [check_newer_available] Checking available: $available_build vs. installer: $installer_build"
        echo "   [check_newer_available] Checking darwin: $available_build_darwin vs. installer: $installer_build_darwin"
        echo "   [check_newer_available] Checking letter: $available_build_letter vs. installer: $installer_build_letter"
        echo "   [check_newer_available] Checking minor: $available_build_minor vs. installer: $installer_build_minor"
        if [[ $available_build_darwin -gt $installer_build_darwin ]]; then
            echo "   [check_newer_available] $available_build > $installer_build"
            newer_build_found="yes"
            # break
        elif [[ $available_build_letter > $installer_build_letter && $available_build_darwin -eq $installer_build_darwin ]]; then
            echo "   [check_newer_available] $available_build > $installer_build"
            newer_build_found="yes"
            # break
        elif [[ ! $available_build_minor_beta && $installer_build_minor_beta && $available_build_letter == "$installer_build_letter" && $available_build_darwin -eq $installer_build_darwin ]]; then
            echo "   [check_newer_available] $available_build > $installer_build (production > beta)"
            newer_build_found="yes"
            # break
        elif [[ ! $available_build_minor_beta && ! $installer_build_minor_beta && $available_build_minor_no -lt 1000 && $installer_build_minor_no -lt 1000 && $available_build_minor_no -gt $installer_build_minor_no && $available_build_letter == "$installer_build_letter" && $available_build_darwin -eq $installer_build_darwin ]]; then
            echo "   [check_newer_available] $available_build > $installer_build"
            newer_build_found="yes"
            # break
        elif [[ ! $available_build_minor_beta && ! $installer_build_minor_beta && $available_build_minor_no -ge 1000 && $installer_build_minor_no -ge 1000 && $available_build_minor_no -gt $installer_build_minor_no && $available_build_letter == "$installer_build_letter" && $available_build_darwin -eq $installer_build_darwin ]]; then
            echo "   [check_newer_available] $available_build > $installer_build (both betas)"
            newer_build_found="yes"
            # break
        elif [[ $available_build_minor_beta && $installer_build_minor_beta && $available_build_minor_no -ge 1000 && $installer_build_minor_no -ge 1000 && $available_build_minor_no -gt $installer_build_minor_no && $available_build_letter == "$installer_build_letter" && $available_build_darwin -eq $installer_build_darwin ]]; then
            echo "   [check_newer_available] $available_build > $installer_build (both betas)"
            newer_build_found="yes"
        fi
        # i=$((i+1))
    # done
    [[ $newer_build_found != "yes" ]] && echo "   [check_newer_available] No newer builds found"
}

echo "   [check_newer_available] Parameter 1: installer"
echo "   [check_newer_available] Parameter 2: system"

available_build=$1
installer_build=$2

check_newer_available
