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

You can use Jamf Pro parameters 4-10 to supply arguments to erase-install,
and you can supply multiple arguments in one Jamf Pro parameter.

The last parameter can be used to specify the location of erase-install.sh, if
you have deployed a custom version of erase-install at a different location.

KNOWN LIMITATION

Don't add a parameter after a parameter with a value in a single Parameter field in Jamf.
e.g. don't add something like "--os 13 --erase" in the same box.
Parameters without values are ok to put in a single Parameter field in Jamf.
e.g. this is OK: "--erase --reinstall --confirm"
DOC

script_name="erase-install-launcher"

escape_args() {
    temp_string=$(awk 'BEGIN{FS=OFS="\""} {for (i=1;i<=NF;i+=2) gsub(/ /,"§",$i)}1' <<< "$1")
    # temp_string=$(awk -F\" '{OFS="\""; for(i=2;i<NF;i+=2)gsub(/ /,"++",$i);print}' <<< "$1")
    temp_string="${temp_string//\\ /++}"
    echo "$temp_string"
}

if [[ "${11}" != "" ]]; then
    eraseinstall_path="${11}"
else
    eraseinstall_path="/Library/Management/erase-install/erase-install.sh"
fi

echo
echo "[$script_name] Launching ${eraseinstall_path} using the following arguments:"

arguments=()
count=1
for i in {4..10}; do
    # first of all we replace all spaces with a § symbol
    eval_string="${(P)i}"
    parsed_parameter="$(escape_args "$eval_string")"

    # now we have split up the parameter we can put the spaces back
    for p in $parsed_parameter; do
        arguments+=("${p//§/ }")
    done
done

eraseinstall_args=()
for arg in "${arguments[@]}"; do
    if [[ "$arg" == "--"* ]]; then
        # replace any equals after the command with a space
        arg="${arg/=/ }"
        # if the first argument is an option (--*) then any second part should be a value, split it once more
        first_arg=$(cut -d' ' -f1 <<< "$arg")
        if [[ "$first_arg" ]]; then
            eraseinstall_args+=("$first_arg")
            echo "[$count] $first_arg"
            ((count++))
            potential_arg=$(cut -d' ' -f2- <<< "$arg")
            if [[ "$potential_arg" && ("$potential_arg" != "$first_arg") ]]; then
                eraseinstall_args+=("$potential_arg")
                echo "[$count] $potential_arg"
                ((count++))
            fi
        fi
    else
        eraseinstall_args+=("$arg")
        echo "[$count] $arg"
        ((count++))
    fi
done

echo

"${eraseinstall_path}" "${eraseinstall_args[@]}"

rc=$?

echo
echo "[$script_name] Exit ($rc)"
exit $rc
