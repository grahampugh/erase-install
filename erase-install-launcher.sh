#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2296
# these are due to the dynamic variable assignments used in the localization strings

: <<DOC
erase-install-launcher.sh

This script is designed to be used as a stub for launching erase-install.sh when
deploying the standard macOS package of erase-install from within Jamf Pro.

You can simply add this script to the "Scripts" section of a Jamf Pro policy,
which will in turn launch erase-install.sh with all supplied parameters and
return its output and return code back to Jamf Pro.

You can use Jamf Pro parameters 1-10 to supply arguments to erase-install,
and you can supply multiple arguments in one Jamf Pro parameter.

The last parameter can be used to specify the location of erase-install.sh, if
you have deployed a custom version of erase-install at a different location.
DOC

script_name="erase-install-launcher"

escape_args() {
    temp_string=$(awk -F\" '{OFS="\""; for(i=2;i<NF;i+=2)gsub(/ /,"++",$i);print}' <<< "$1")
    temp_string="${temp_string//\\ /++}"
    echo "$temp_string"
}

eraseinstall_args=()
for i in {4..10}; do
    eval_string="${(P)i}"
    parsed_parameter="$(escape_args "$eval_string")"

    for p in $parsed_parameter; do
        if [[ $p =~ \" ]]; then
            eraseinstall_args+=("${p//++/ }")
        else
            eraseinstall_args+=("${p//++/\\ }")
        fi
    done
done

echo "${11}"

if [[ "${11}" != "" ]]; then
    eraseinstall_path="${11}"
else
    eraseinstall_path="/Library/Management/erase-install/erase-install.sh"
fi

echo "[$script_name] Starting script \"${eraseinstall_path}\"" "${eraseinstall_args[@]}"
"${eraseinstall_path}" "${eraseinstall_args[@]}"

rc=$?

echo "[$script_name] Exit ($rc)"
exit $rc
