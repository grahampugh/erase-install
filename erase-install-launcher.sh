#!/bin/bash

:<<DOC
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

IFS=" " read -r -a eraseinstall_args <<< "${4} ${5} ${6} ${7} ${8} ${9} ${10}"
eraseinstall_path="${11:-/Library/Management/erase-install/erase-install.sh}"

echo "[$script_name] Starting script \"${eraseinstall_path}\"" "${eraseinstall_args[@]}"
"${eraseinstall_path}" "${eraseinstall_args[@]}"
rc=$?

echo "[$script_name] Exit ($rc)"
exit $rc
