#!/bin/bash

# macOS Installer Script

# Set a default OS name 
os_name="Mojave"

# Get OS name from script parameter
[[ $1 ]] && os_name="$1"
[[ $4 ]] && os_name="$4"
    

# scope to computers where Application Title is Install macOS Mojave.app
macOSinstaller="/Applications/Install macOS $os_name.app"

# Jamf Pro specific stuff - will be ignored if Jam Helper tool not present
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

jh_title="Downloading macOS $os_name"
jh_desc="macOS $os_name is now installing on your device. You will not be warned when the computer restarts!"
jh_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
jh_iconsize=100

# open jamf helper tool
if [[ -f "$jamfHelper" ]]; then
    "$jamfHelper" -windowType hud -windowPosition ul -title "$jh_title" -alignHeading center -alignDescription left -description "$jh_desc" -lockHUD -icon "$jh_icon" -iconSize $jh_iconsize &
    jamfPID=$(echo $!)
fi

# extra parameter required for macOS <=10.13
[[ $os_name != "Mojave" ]] && app_path_param="--applicationpath \"$macOSinstaller\"" || app_path_param=""

# run the installer
"$macOSinstaller/Contents/Resources/startosinstall" --volume $1 --rebootdelay 10 $app_path_param --nointeraction

# kill the helper tool and Self Service
[[ $jamfPID ]] && kill $jamfPID
/usr/bin/killall "Self Service"
