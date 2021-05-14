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
# See README.md for details on use.
#
# Requirements:
# macOS 10.13.4+ is already installed on the device (for eraseinstall option)
# Device file system is APFS

# shellcheck disable=SC2034
# this is due to the dynamic variable assignments used in the localization strings
# shellcheck disable=SC2001
# this is to use sed in the case statements


# Version:
version="0.20.1"

# all output is written also to a log file
LOG_FILE=/var/log/erase-install.log
exec > >(tee ${LOG_FILE}) 2>&1

# URL for downloading installinstallmacos.py
installinstallmacos_url="https://raw.githubusercontent.com/grahampugh/macadmin-scripts/master/installinstallmacos.py"

# Directory in which to place the macOS installer. Overridden with --path
installer_directory="/Applications"

# Temporary working directory
workdir="/Library/Management/erase-install"

# place any extra packages that should be installed as part of the erase-install into this folder. The script will find them and install.
# https://derflounder.wordpress.com/2017/09/26/using-the-macos-high-sierra-os-installers-startosinstall-tool-to-install-additional-packages-as-post-upgrade-tasks/
extras_directory="$workdir/extras"

# Dialog helper apps
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
DEP_NOTIFY_APP="/Applications/Utilities/DEPNotify.app"
DEP_NOTIFY_LOG="/var/tmp/depnotify.log"
DEP_NOTIFY_CONFIRMATION_FILE="/var/tmp/com.depnotify.provisioning.done"

# Dialogue localizations - download window
dialog_dl_title_en="Downloading macOS"
dialog_dl_title_de="Download macOS"
dialog_dl_title_nl="Downloaden macOS"

dialog_dl_desc_en="We need to download the macOS installer to your computer; this will take several minutes."
dialog_dl_desc_de="Der macOS Installer wird heruntergeladen, dies dauert mehrere Minuten."
dialog_dl_desc_nl="We moeten het macOS besturingssysteem downloaden, dit duurt enkele minuten."

# Dialogue localizations - erase lockscreen
dialog_erase_title_en="Erasing macOS"
dialog_erase_title_de="macOS Wiederherstellen"
dialog_erase_title_nl="macOS Herinstalleren"

dialog_erase_desc_en="Preparing the installer may take up to 30 minutes. Once completed your computer will reboot and continue the reinstallation."
dialog_erase_desc_de="Das Vorbereiten des Installationsprogramms kann bis zu 30 Minuten dauern. Nach Abschluss wird Ihr Computer neu gestartet und die Neuinstallation fortgesetzt."
dialog_erase_desc_nl="Het voorbereiden van het installatieprogramma kan tot 30 minuten duren. Zodra het proces is voltooid, wordt uw computer opnieuw opgestart en wordt de herinstallatie voortgezet."

# Dialogue localizations - reinstall lockscreen
dialog_reinstall_title_en="Upgrading macOS"
dialog_reinstall_title_de="Upgrading macOS"
dialog_reinstall_title_nl="macOS upgraden"

dialog_reinstall_status_en="Preparing macOS for reinstallation"
dialog_reinstall_status_de="Vorbereiten von macOS für die Neuinstallation"
dialog_reinstall_status_nl="MacOS voorbereiden voor herinstallatie"

dialog_reinstall_heading_en="Please wait as we prepare your computer for upgrading macOS."
dialog_reinstall_heading_de="Bitte warten, das Upgrade macOS wird ausgeführt."
dialog_reinstall_heading_nl="Even geduld terwijl we uw computer voorbereiden voor de upgrade van macOS."

dialog_reinstall_desc_en="This process may take up to 30 minutes. Once completed your computer will reboot and begin the upgrade."
dialog_reinstall_desc_de="Dieser Prozess benötigt bis zu 30 Minuten. Der Mac startet anschliessend neu und beginnt mit dem Update."
dialog_reinstall_desc_nl="Dit proces duurt ongeveer 30 minuten. Zodra dit is voltooid, wordt uw computer opnieuw opgestart en begint de upgrade."

# Dialogue localizations - confirmation window
dialog_confirmation_title_en="Erasing macOS"
dialog_confirmation_title_de="macOS wiederherstellen"
dialog_confirmation_title_nl="macOS wissen"

dialog_confirmation_desc_en="Please confirm that you want to ERASE ALL DATA FROM THIS DEVICE and reinstall macOS"
dialog_confirmation_desc_de="Bitte bestätigen, dass Sie ALLE DATEN VON DIESEM GERÄT LÖSCHEN und macOS neu installieren wollen"
dialog_confirmation_desc_nl="Weet je zeker dat je ALLE GEGEVENS VAN DIT APPARAAT WILT WISSEN en macOS opnieuw installeert?"

dialog_confirmation_status_en="Press Cmd + Ctrl + C to Cancel"
dialog_confirmation_status_de="Drücken Sie Cmd + Ctrl + C zum Abbrechen"
dialog_confirmation_status_nl="Druk op Cmd + Ctrl + C om te Annuleren"

# Dialogue buttons
dialog_confirmation_button_en="Confirm"
dialog_confirmation_button_de="Bestätigen"
dialog_confirmation_button_nl="Ja"

dialog_cancel_button_en="Stop"
dialog_cancel_button_de="Abbrechen"
dialog_cancel_button_nl="Annuleren"

dialog_enter_button_en="Enter"
dialog_enter_button_de="Eingeben"
dialog_enter_button_nl="Enter"

# Dialogue localizations - free space check
dialog_check_desc_en="The macOS upgrade cannot be installed as there is not enough space left on the drive."
dialog_check_desc_de="Das macOS-Upgrade kann nicht installiert werden, da nicht genügend Speicherplatz auf dem Laufwerk vorhanden ist."
dialog_check_desc_nl="De macOS-upgrade kan niet worden geïnstalleerd op een computer met minder dan 45 GB schijfruimte."

# Dialogue localizations - power check
dialog_power_title_en="Waiting for AC Power Connection"
dialog_power_title_de="Warten auf AC-Netzteil"
dialog_power_title_nl="Wachten op Stroomadapter"

dialog_power_desc_en="Please connect your computer to power using an AC power adapter. This process will continue once AC power is detected."
dialog_power_desc_de="Bitte schließen Sie Ihren Computer mit einem AC-Netzteil an das Stromnetz an. Dieser Prozess wird fortgesetzt, sobald die AC-Stromversorgung erkannt wird."
dialog_power_desc_nl="Sluit uw computer aan met de stroomadapter. Zodra deze is gedetecteerd gaat het proces verder"

# Dialogue localizations - ask for short name
dialog_short_name_en="Please enter an account name to start the reinstallation process"
dialog_short_name_de="Bitte geben Sie einen Kontonamen ein, um die Neuinstallation zu starten"
dialog_short_name_nl="Voer een accountnaam in om het installatieproces te starten"

# Dialogue localizations - ask for password
dialog_not_volume_owner_en="account is not a Volume Owner! Please login using one of the following accounts and try again"
dialog_not_volume_owner_de="Konto ist kein Volume-Besitzer! Bitte melden Sie sich mit einem der folgenden Konten an und versuchen Sie es erneut"
dialog_not_volume_owner_nl="Account is geen volume-eigenaar! Log in met een van de volgende accounts en probeer het opnieuw"

# Dialogue localizations - invalid user
dialog_invalid_user_en="This account cannot be used to to perform the reinstall"
dialog_invalid_user_de="Dieses Konto kann nicht zur Durchführung der Neuinstallation verwendet werden"
dialog_invalid_user_nl="Dit account kan niet worden gebruikt om de herinstallatie uit te voeren"

# Dialogue localizations - invalid password
dialog_invalid_password_en="ERROR: The password entered is NOT the login password for"
dialog_invalid_password_de="ERROR: Das eingegebene Kennwort ist NICHT das Anmeldekennwort für"
dialog_invalid_password_nl="FOUT: Het ingevoerde wachtwoord is NIET het inlogwachtwoord voor"

# Dialogue localizations - not a volume owner
dialog_get_password_en="Please enter the password for the account"
dialog_get_password_de="Bitte geben Sie das Passwort für das Konto ein"
dialog_get_password_nl="Voer het wachtwoord voor het account in"

# icon for download window
dialog_dl_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns"

# icon for confirmation dialog
dialog_confirmation_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

# Grab currently logged in user to set the language for Dialogue messages
current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
language=$(/usr/libexec/PlistBuddy -c 'print AppleLanguages:0' "/Users/${current_user}/Library/Preferences/.GlobalPreferences.plist")
if [[ $language = de* ]]; then
    user_language="de"
elif [[ $language = nl* ]]; then
    user_language="nl"
else
    user_language="en"
fi

# set localisation variables
dialog_dl_title=dialog_dl_title_${user_language}
dialog_dl_desc=dialog_dl_desc_${user_language}
dialog_erase_title=dialog_erase_title_${user_language}
dialog_erase_desc=dialog_erase_desc_${user_language}
dialog_reinstall_title=dialog_reinstall_title_${user_language}
dialog_reinstall_heading=dialog_reinstall_heading_${user_language}
dialog_reinstall_desc=dialog_reinstall_desc_${user_language}
dialog_reinstall_status=dialog_reinstall_status_${user_language}
dialog_confirmation_title=dialog_confirmation_title_${user_language}
dialog_confirmation_desc=dialog_confirmation_desc_${user_language}
dialog_confirmation_status=dialog_confirmation_status_${user_language}
dialog_confirmation_button=dialog_confirmation_button_${user_language}
dialog_cancel_button=dialog_cancel_button_${user_language}
dialog_enter_button=dialog_enter_button_${user_language}
dialog_check_desc=dialog_check_desc_${user_language}
dialog_power_desc=dialog_power_desc_${user_language}
dialog_power_title=dialog_power_title_${user_language}
dialog_short_name=dialog_short_name_${user_language}
dialog_invalid_user=dialog_invalid_user_${user_language}
dialog_get_password=dialog_get_password_${user_language}
dialog_invalid_password=dialog_invalid_password_${user_language}
dialog_not_volume_owner=dialog_not_volume_owner_${user_language}

kill_process() {
    process="$1"
    if /usr/bin/pgrep -a "$process" >/dev/null ; then 
        /usr/bin/pkill -a "$process" && echo "   [erase-install] '$process' ended" || \
        echo "   [erase-install] '$process' could not be killed"
    fi
}

dep_notify() {
    # configuration taken from https://github.com/jamf/DEPNotify-Starter
    DEP_NOTIFY_CONFIG_PLIST="/Users/$current_user/Library/Preferences/menu.nomad.DEPNotify.plist"
    # /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" pathToPlistFile "$DEP_NOTIFY_USER_INPUT_PLIST"
    STATUS_TEXT_ALIGN="center"
    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" statusTextAlignment "$STATUS_TEXT_ALIGN"
    chown "$current_user":staff "$DEP_NOTIFY_CONFIG_PLIST"

    # Configure the window's look
    echo "Command: Image: $dn_icon" >> "$DEP_NOTIFY_LOG"
    echo "Command: MainTitle: $dn_title" >> "$DEP_NOTIFY_LOG"
    echo "Command: MainText: $dn_desc" >> "$DEP_NOTIFY_LOG"
    if [[ $dn_button ]]; then
        echo "Command: ContinueButton: $dn_button" >> "$DEP_NOTIFY_LOG"
    fi

    if ! pgrep DEPNotify ; then
        # Opening the app after initial configuration
        if [[ "$window_type" == "fs" ]]; then
            sudo -u "$current_user" open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG" -fullScreen
        else
            sudo -u "$current_user" open -a "$DEP_NOTIFY_APP" --args -path "$DEP_NOTIFY_LOG"
        fi
    fi

    # set message below progress bar
    echo "Status: $dn_status" >> "$DEP_NOTIFY_LOG"

    # set alternaitve quit key (default is X)
    if [[ $dn_quit_key ]]; then
        echo "Command: QuitKey: $dn_quit_key" >> "$DEP_NOTIFY_LOG"
    fi

}

dep_notify_quit() {
    # quit DEP Notify
    echo "Command: Quit" >> "$DEP_NOTIFY_LOG"
    # reset all the settings that might be used again
    rm "$DEP_NOTIFY_LOG" "$DEP_NOTIFY_CONFIRMATION_FILE" 2>/dev/null
    dn_button=""
    dn_quit_key=""
    dn_cancel=""
}

ask_for_shortname() {
    # required for Silicon Macs
    /usr/bin/osascript <<EOT
        set nameentry to text returned of (display dialog "${!dialog_short_name}" default answer "" buttons {"${!dialog_enter_button}", "${!dialog_cancel_button}"} default button 1 with icon 2)
EOT
}

invalid_user() {
    # required for Silicon Macs
    /usr/bin/osascript <<EOT
        display dialog "$account_shortname: ${!dialog_invalid_user}" buttons {"OK"} default button 1 with icon 2
EOT
}

user_not_volume_owner() {
    # required for Silicon Macs
    /usr/bin/osascript <<EOT
        display dialog "$account_shortname ${!dialog_not_volume_owner}: ${enabled_users}" buttons {"OK"} default button 1 with icon 2
EOT
}

ask_for_password() {
    # required for Silicon Macs
    /usr/bin/osascript <<EOT
        set nameentry to text returned of (display dialog "${!dialog_get_password} ($account_shortname)" default answer "" with hidden answer buttons {"${!dialog_enter_button}", "${!dialog_cancel_button}"} default button 1 with icon 2)
EOT
}

check_password() {
    # Check that the password entered matches actual password
    # required for Silicon Macs
    # thanks to Dan Snelson for the idea
    user="$1"
    password="$2"
	password_matches=$( /usr/bin/dscl /Search -authonly "$user" "$password" )
	if [[ -z "${password_matches}" ]]; then
		echo "   [check_password] Success: the password entered is the correct login password for $user."
	else
		echo "   [check_password] ERROR: The password entered is NOT the login password for $user."
        /usr/bin/osascript <<EOT
            display dialog "${!dialog_invalid_user} $user." buttons {"OK"} default button 1 with icon 2
EOT
    exit 1
	fi
}

get_user_details() {
    # Apple Silicon devices require a username and password to run startosinstall
    # get account name (short name)
    if [[ $use_current_user == "yes" ]]; then
        account_shortname="$current_user"
    fi

    if [[ $account_shortname == "" ]]; then
        if ! account_shortname=$(ask_for_shortname) ; then
            echo "   [get_user_details] Use cancelled."
            exit 1
        fi
    fi

    # check that this user exists and is in the staff group (so not some system user)
    if ! /usr/sbin/dseditgroup -o checkmember -m "$account_shortname" staff ; then
        echo "   [get_user_details] $account_shortname account cannot be used to perform reinstallation!"
        invalid_user
        exit 1
    fi

    # if we are performing eraseinstall the user needs to be an admin so let's promote the user
    if [[ $erase == "yes" ]]; then
        if ! /usr/sbin/dseditgroup -o checkmember -m "$account_shortname" admin ; then
            if /usr/sbin/dseditgroup -o edit -a "$account_shortname" admin ; then
                echo "   [get_user_details] $account_shortname account has been promoted to admin so that eraseinstall can proceed"
                promoted_user="$account_shortname"
            else
                echo "   [get_user_details] $account_shortname account could not be promoted to admin so eraseinstall cannot proceed"
                invalid_user
                exit 1
            fi
        fi
    fi

    # check that the user is a Volume Owner
    user_is_volume_owner=0
    users=$(/usr/sbin/diskutil apfs listUsers /)
    enabled_users=""
    while read -r line ; do
        user=$(/usr/bin/cut -d, -f1 <<< "$line")
        guid=$(/usr/bin/cut -d, -f2 <<< "$line")
        if [[ $(/usr/bin/grep -A2 "$guid" <<< "$users" | /usr/bin/tail -n1 | /usr/bin/awk '{print $NF}') == "Yes" ]]; then
            enabled_users+="$user "  
            if [[ "$account_shortname" == "$user" ]]; then
                echo "   [get_user_details] $account_shortname is a Volume Owner"
                user_is_volume_owner=1
            fi
        fi
    done <<< "$(/usr/bin/fdesetup list)"
    if [[ $enabled_users != "" && $user_is_volume_owner = 0 ]]; then
        echo "   [get_user_details] $account_shortname is not a Volume Owner"
        user_not_volume_owner
        exit 1
    fi

    # get password and check that the password is correct
    if ! account_password=$(ask_for_password) ; then
        echo "   [get_user_details] Use cancelled."
        exit 1
    fi
    check_password "$account_shortname" "$account_password"
}

wait_for_power() {
    process="$1"
    ## Loop for "power_wait_timer" seconds until either AC Power is detected or the timer is up
    echo "   [wait_for_power] Waiting for AC power..."
    while [[ "$power_wait_timer" -gt 0 ]]; do
        if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
            echo "   [wait_for_power] OK - AC power detected"
            kill_process "$process"
            return
        fi
        sleep 1
        ((power_wait_timer--))
    done
    kill_process "$process"
    echo "   [wait_for_power] ERROR - No AC power detected, cannot continue."
    exit 1
}

check_power_status() {
    # Check if device is on battery or AC power
    # If not, and our power_wait_timer is above 1, allow user to connect to power for specified time period
    # Acknowledgements: https://github.com/kc9wwh/macOSUpgrade/blob/master/macOSUpgrade.sh

    # set default wait time to 60 seconds
    [[ ! $power_wait_timer ]] && power_wait_timer=60

    if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
        echo "   [check_power_status] OK - AC power detected"
    else
        echo "   [check_power_status] WARNING - No AC power detected"
        if [[ "$power_wait_timer" -gt 0 ]]; then
            if [[ -f "$jamfHelper" ]]; then
                # use jamfHelper if possible
                "$jamfHelper" -windowType "utility" -title "${!dialog_power_title}" -description "${!dialog_power_desc}" -alignDescription "left" -icon "$dialog_confirmation_icon" &
                wait_for_power "jamfHelper"
            else
                /usr/bin/osascript -e "display dialog \"${!dialog_power_desc}\" buttons {\"OK\"} default button \"OK\" with icon stop" &
                wait_for_power "osascript"
            fi
        else
            echo "   [check_power_status] ERROR - No AC power detected, cannot continue."
            exit 1
        fi
    fi
}

free_space_check() {
    free_disk_space=$(df -Pk . | column -t | sed 1d | awk '{print $4}')
    
    min_drive_bytes=$(( min_drive_space * 1000000 ))
    echo $min_drive_bytes
    if [[ $free_disk_space -ge $min_drive_bytes ]]; then
        echo "   [free_space_check] OK - $free_disk_space KB free disk space detected"
    else
        echo "   [free_space_check] ERROR - $free_disk_space KB free disk space detected"
        if [[ -f "$jamfHelper" ]]; then
            "$jamfHelper" -windowType "utility" -description "${!dialog_check_desc}" -alignDescription "left" -icon "$dialog_confirmation_icon" -button1 "OK" -defaultButton "0" -cancelButton "1"
        else
            /usr/bin/osascript -e "display dialog \"${!dialog_check_desc}\" buttons {\"OK\"} default button \"OK\" with icon stop"
        fi
        exit 1
    fi
}

check_installer_is_valid() {
    echo "   [check_installer_is_valid] Checking validity of $installer_app."
    # check installer validity:
    # The Build version in the app Info.plist is often older than the advertised build, 
    # so it's not a great check for validity
    # check if running --erase, where we might be using the same build.
    # The actual build number is found in the SharedSupport.dmg in com_apple_MobileAsset_MacSoftwareUpdate.xml (Big Sur and greater).
    # This is new from Big Sur, so we include a fallback to the Info.plist file just in case. 

    # first ensure that some earlier instance is not still mounted as it might interfere with the check
    [[ -d "/Volumes/Shared Support" ]] && diskutil unmount force "/Volumes/Shared Support"
    # now attempt to mount
    if hdiutil attach -quiet -noverify "$installer_app/Contents/SharedSupport/SharedSupport.dmg" ; then
        build_xml="/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
        if [[ -f "$build_xml" ]]; then
            echo "   [check_installer_is_valid] Using Build value from com_apple_MobileAsset_MacSoftwareUpdate.xml"
            installer_build=$(/usr/libexec/PlistBuddy -c "Print :Assets:0:Build" "$build_xml")
            sleep 1
            diskutil unmount force "/Volumes/Shared Support"
        fi
    else
        # if that fails, fallback to the method for 10.15 or less, which is less accurate
        echo "   [check_installer_is_valid] Using DTSDKBuild value from Info.plist"
        installer_build=$( /usr/bin/defaults read "$installer_app/Contents/Info.plist" DTSDKBuild )
    fi

    system_build=$( /usr/bin/sw_vers -buildVersion )

    # we need to break the build into component parts to compare versions
    # 1. Darwin version is older in the installer than on the system
    if [[ ${installer_build:0:2} -lt ${system_build:0:2} ]]; then 
        invalid_installer_found="yes"
    # 2. Darwin version matches but build letter (minor version) is older in the installer than on the system
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} < ${system_build:2:1} ]]; then
        invalid_installer_found="yes"
    # 3. Darwin version and build letter (minor version) matches but the first two build version numbers are older in the installer than on the system
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} == "${system_build:2:1}" && ${installer_build:3:2} -lt ${system_build:3:2} ]]; then
        echo "   [check_installer_is_valid] Warning: $installer_build < $system_build - find newer installer if this one fails"
    elif [[ ${installer_build:0:2} -eq ${system_build:0:2} && ${installer_build:2:1} == "${system_build:2:1}" && ${installer_build:3:2} -eq ${system_build:3:2} ]]; then
        installer_build_minor=${installer_build:5:2}
        system_build_minor=${system_build:5:2}
        # 4. Darwin version, build letter (minor version) and first two build version numbers match, but the second two build version numbers are older in the installer than on the system
        if [[ ${installer_build_minor//[!0-9]/} -lt ${system_build_minor//[!0-9]/} ]]; then
        echo "   [check_installer_is_valid] Warning: $installer_build < $system_build - find newer installer if this one fails"
        # 5. Darwin version, build letter (minor version) and build version numbers match, but beta release letter is older in the installer than on the system (unlikely to ever happen, but just in case)
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

check_installassistant_pkg_is_valid() {
    echo "   [check_installassistant_pkg_is_valid] Checking validity of $installer_pkg."
    # check InstallAssistant pkg validity
    # packages generated by installinstallmacos.py have the format InstallAssistant-version-build.pkg
    # Extracting an actual version from the package is slow as the entire package must be unpackaged
    # to read the PackageInfo file. 
    # We are here YOLOing the filename instead. Of course it could be spoofed, but that would not be
    # in anyone's interest to attempt as it will just make the script eventually fail.
    installer_pkg_build=$( basename "$installer_pkg" | sed 's|.pkg||' | cut -d'-' -f 3 )
    system_build=$( /usr/bin/sw_vers -buildVersion )
    if [[ "$installer_pkg_build" < "$system_build" ]]; then
        echo "   [check_installassistant_pkg_is_valid] $installer_pkg_build < $system_build so not valid."
        installassistant_pkg="$installer_pkg"
        invalid_installer_found="yes"
    else
        echo "   [check_installassistant_pkg_is_valid] $installer_pkg_build >= $system_build so valid."
        installassistant_pkg="$installer_pkg"
    fi

    install_macos_app="$installer_app"
}

find_existing_installer() {
    # Search for an existing download
    # First let's see if this script has been run before and left an installer
    macos_dmg=$( find $workdir/*.dmg -maxdepth 1 -type f -print -quit 2>/dev/null )
    macos_sparseimage=$( find $workdir/*.sparseimage -maxdepth 1 -type f -print -quit 2>/dev/null )
    installer_app=$( find "$installer_directory/Install macOS"*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    installer_pkg=$( find $workdir/InstallAssistant*.pkg -maxdepth 1 -type f -print -quit 2>/dev/null )

    if [[ -f "$macos_dmg" ]]; then
        echo "   [find_existing_installer] Installer image found at $macos_dmg."
        hdiutil attach "$macos_dmg"
        installer_app=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        check_installer_is_valid
    elif [[ -f "$macos_sparseimage" ]]; then
        echo "   [find_existing_installer] Installer sparse image found at $macos_sparseimage."
        hdiutil attach "$macos_sparseimage"
        installer_app=$( find '/Volumes/'*macOS*/Applications/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        check_installer_is_valid
    elif [[ -d "$installer_app" ]]; then
        echo "   [find_existing_installer] Installer found at $installer_app."
        app_is_in_applications_folder="yes"
        check_installer_is_valid
    elif [[ -f "$installer_pkg" ]]; then
        echo "   [find_existing_installer] InstallAssistant package found at $installer_pkg."
        check_installassistant_pkg_is_valid
    else
        echo "   [find_existing_installer] No valid installer found."
    fi
}

overwrite_existing_installer() {
    echo "   [overwrite_existing_installer] Overwrite option selected. Deleting existing version."
    existing_installer=$( find /Volumes/*macOS* -maxdepth 2 -type d -name "Install*.app" -print -quit 2>/dev/null )
    if [[ -d "$existing_installer" ]]; then
        echo "   [erase-install] Mounted installer will be unmounted: $existing_installer"
        existing_installer_mount_point=$(echo "$existing_installer" | cut -d/ -f 1-3)
        diskutil unmount force "$existing_installer_mount_point"
    fi
    rm -f "$macos_dmg" "$macos_sparseimage"
    rm -rf "$installer_app"
    app_is_in_applications_folder=""
}

move_to_applications_folder() {
    if [[ $app_is_in_applications_folder == "yes" ]]; then
        echo "   [move_to_applications_folder] Valid installer already in $installer_directory folder"
        return
    fi

    # if dealing with a package we now have to extract it and check it's valid
    if [[ -f "$installassistant_pkg" ]]; then
        echo "   [move_to_applications_folder] Extracting $installassistant_pkg to /Applications folder"
        /usr/sbin/installer -pkg "$installassistant_pkg" -tgt /
        install_macos_app=$( find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null )
        if [[ -d "$install_macos_app" && "$keep_pkg" != "yes" ]]; then
            echo "   [move_to_applications_folder] Deleting $installassistant_pkg"
            rm -f "$installassistant_pkg"
        fi
        return
    fi

    echo "   [move_to_applications_folder] Moving installer to $installer_directory folder"
    cp -R "$install_macos_app" $installer_directory/
    existing_installer=$( find /Volumes/*macOS* -maxdepth 2 -type d -name "Install*.app" -print -quit 2>/dev/null )
    if [[ -d "$existing_installer" ]]; then
        echo "   [move_to_applications_folder] Mounted installer will be unmounted: $existing_installer"
        existing_installer_mount_point=$(echo "$existing_installer" | cut -d/ -f 1-3)
        diskutil unmount force "$existing_installer_mount_point"
    fi
    rm -f "$macos_dmg" "$macos_sparseimage"
    echo "   [move_to_applications_folder] Installer moved to $installer_directory folder"
}

find_extra_packages() {
    # set install_package_list to blank.
    install_package_list=()
    for file in "$extras_directory"/*.pkg; do
        if [[ $file != *"/*.pkg" ]]; then
            echo "   [find_extra_installers] Additional package to install: $file"
            install_package_list+=("--installpackage")
            install_package_list+=("$file")
        fi
    done
}

set_seedprogram() {
    if [[ $seedprogram ]]; then
        echo "   [set_seedprogram] $seedprogram seed program selected"
        /System/Library/PrivateFrameworks/Seeding.framework/Versions/A/Resources/seedutil enroll "$seedprogram" >/dev/null
        # /usr/sbin/softwareupdate -l -a >/dev/null
    else
        echo "   [set_seedprogram] Standard seed program selected"
        /System/Library/PrivateFrameworks/Seeding.framework/Versions/A/Resources/seedutil unenroll >/dev/null
        # /usr/sbin/softwareupdate -l -a >/dev/null
    fi
    sleep 5
    current_seed=$(/System/Library/PrivateFrameworks/Seeding.framework/Versions/A/Resources/seedutil current | grep "Currently enrolled in:" | sed 's|Currently enrolled in: ||')
    echo "   [set_seedprogram] Currently enrolled in $current_seed seed program."
}

list_full_installers() {
    # for 10.15.7 and above we can use softwareupdate --list-full-installers
    set_seedprogram
    echo
    /usr/sbin/softwareupdate --list-full-installers
}

run_fetch_full_installer() {
    # for 10.15+ we can use softwareupdate --fetch-full-installer
    set_seedprogram

    softwareupdate_args=''
    if [[ $prechosen_version ]]; then
        echo "   [run_fetch_full_installer] Trying to download version $prechosen_version"
        softwareupdate_args+=" --full-installer-version $prechosen_version"
    fi
    # now download the installer
    echo "   [run_fetch_full_installer] Running /usr/sbin/softwareupdate --fetch-full-installer $softwareupdate_args"
    # shellcheck disable=SC2086
    /usr/sbin/softwareupdate --fetch-full-installer $softwareupdate_args

    # shellcheck disable=SC2181
    if [[ $? == 0 ]]; then
        # Identify the installer
        if find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null ; then
            install_macos_app=$( find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null )
            # if we actually want to use this installer we should check that it's valid
            if [[ $erase == "yes" || $reinstall == "yes" ]]; then 
                check_installer_is_valid
                if [[ $invalid_installer_found == "yes" ]]; then
                    echo "   [run_fetch_full_installer] The downloaded app is invalid for this computer. Try with --version or without --fetch-full-installer"
                    kill_process jamfHelper
                    exit 1
                fi
            fi
        else
            echo "   [run_fetch_full_installer] No install app found. I guess nothing got downloaded."
            kill_process jamfHelper
            exit 1
        fi
    else
        echo "   [run_fetch_full_installer] softwareupdate --fetch-full-installer failed. Try without --fetch-full-installer option."
        kill_process jamfHelper
        exit 1
    fi
}

get_installinstallmacos() {
    # grab installinstallmacos.py if not already there
    if [[ ! -d "$workdir" ]]; then
        echo "   [get_installinstallmacos] Making working directory at $workdir"
        mkdir -p $workdir
    fi

    if [[ ! -f "$workdir/installinstallmacos.py" || $force_installinstallmacos == "yes" ]]; then
        if [[ ! $no_curl ]]; then
            echo "   [get_installinstallmacos] Downloading installinstallmacos.py..."
            curl -H 'Cache-Control: no-cache' -s $installinstallmacos_url > "$workdir/installinstallmacos.py"
        fi
    fi
    # check it did actually get downloaded
    if [[ ! -f "$workdir/installinstallmacos.py" ]]; then
        echo "Could not download installinstallmacos.py so cannot continue."
        exit 1
    else
        echo "   [get_installinstallmacos] installinstallmacos.py is in $workdir"
        iim_downloaded=1
    fi
       
}

check_newer_available() {
    # Download installinstallmacos.py
    get_installinstallmacos

    # run installinstallmacos.py with list and then interrogate the plist
    [[ ! -f "$python_path" ]] && python_path=$(which python)
    "$python_path" "$workdir/installinstallmacos.py" --list --workdir="$workdir" > /dev/null
    i=0
    newer_build_found="no"
    while available_build=$( /usr/libexec/PlistBuddy -c "Print :result:$i:build" "$workdir/softwareupdate.plist" 2>/dev/null); do
        if [[ $available_build > $installer_build ]]; then
            echo "   [check_newer_available] $available_build > $installer_build"
            newer_build_found="yes"
            break
        fi
        i=$((i+1))
    done
    [[ $newer_build_found != "yes" ]] && echo "   [check_newer_available] No newer builds found"
}

run_installinstallmacos() {
    # Download installinstallmacos.py
    get_installinstallmacos

    # Use installinstallmacos.py to download the desired version of macOS
    installinstallmacos_args=''

    if [[ $list == "yes" ]]; then
        echo "   [run_installinstallmacos] List only mode chosen"
        installinstallmacos_args+="--list "
        installinstallmacos_args+="--warnings "
    else
        installinstallmacos_args+="--workdir=$workdir "
        installinstallmacos_args+="--ignore-cache "
    fi

    if [[ $pkg_installer ]]; then 
        installinstallmacos_args+="--pkg "
    else
        installinstallmacos_args+="--raw "
    fi

    if [[ $catalogurl ]]; then
        echo "   [run_installinstallmacos] Non-standard catalog URL selected"
        installinstallmacos_args+="--catalogurl $catalogurl "
    elif [[ $seedprogram ]]; then
        echo "   [run_installinstallmacos] Non-standard seedprogram selected"
        installinstallmacos_args+="--seedprogram $seedprogram "
    fi

    if [[ $beta == "yes" ]]; then
        echo "   [run_installinstallmacos] Beta versions included"
        installinstallmacos_args+="--beta "
    fi

    if [[ $prechosen_os ]]; then
        echo "   [run_installinstallmacos] Checking that selected OS $prechosen_os is available"
        installinstallmacos_args+="--os=$prechosen_os "
        [[ ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]] && installinstallmacos_args+="--validate "

    elif [[ $prechosen_version ]]; then
        echo "   [run_installinstallmacos] Checking that selected version $prechosen_version is available"
        installinstallmacos_args+="--version=$prechosen_version "
        [[ ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]] && installinstallmacos_args+="--validate "

    elif [[ $prechosen_build ]]; then
        echo "   [run_installinstallmacos] Checking that selected build $prechosen_build is available"
        installinstallmacos_args+="--build=$prechosen_build "
        [[ ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]] && installinstallmacos_args+="--validate "
    fi

    if [[ $samebuild == "yes" ]]; then
        echo "   [run_installinstallmacos] Checking that current build $system_build is available"
        installinstallmacos_args+="--current "

    elif [[ $sameos == "yes" ]]; then
        echo "   [run_installinstallmacos] Checking that current OS $system_os_major.$system_os_version is available"
        if [[ $system_os_major == "10" ]]; then
            installinstallmacos_args+="--os=$system_os_major.$system_os_version "
        else
            installinstallmacos_args+="--os=$system_os_major "
        fi
        if [[ $skip_validation != "yes" ]]; then
            [[ $erase == "yes" || $reinstall == "yes" ]] && installinstallmacos_args+="--validate "
        fi
    fi

    if [[ $list != "yes" && ! $prechosen_os && ! $prechosen_version && ! $prechosen_build && ! $samebuild ]]; then
        echo "   [run_installinstallmacos] Getting current production version"
        installinstallmacos_args+="--auto "
    fi

    # TEST 
    echo
    echo "   [run_installinstallmacos] This command is now being run:"
    echo
    echo "   installinstallmacos.py $installinstallmacos_args"

    # shellcheck disable=SC2086
    if ! python "$workdir/installinstallmacos.py" $installinstallmacos_args ; then
        echo "   [run_installinstallmacos] Error obtaining valid installer. Cannot continue."
        kill_process jamfHelper
        echo
        exit 1
    fi

    if [[ $list == "yes" ]]; then
        exit 0
    fi

    # Identify the installer dmg
    macos_dmg=$( find $workdir -maxdepth 1 -name 'Install_macOS*.dmg' -type f -print -quit )
    macos_sparseimage=$( find $workdir -maxdepth 1 -name 'Install_macOS*.sparseimage' -type f -print -quit )
    installer_pkg=$( find $workdir/InstallAssistant*.pkg -maxdepth 1 -type f -print -quit 2>/dev/null )

    if [[ -f "$macos_dmg" ]]; then
        echo "   [run_installinstallmacos] Mounting disk image to identify installer app."
        hdiutil attach "$macos_dmg"
        install_macos_app=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    elif [[ -f "$macos_sparseimage" ]]; then
        echo "   [run_installinstallmacos] Mounting sparse disk image to identify installer app."
        hdiutil attach "$macos_sparseimage"
        install_macos_app=$( find '/Volumes/'*macOS*/Applications/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    elif [[ -f "$installer_pkg" ]]; then
        echo "   [run_installinstallmacos] InstallAssistant package downloaded."
    else
        echo "   [run_installinstallmacos] No disk image found. I guess nothing got downloaded."
        kill_process jamfHelper
        exit 1
    fi
}

# Functions
show_help() {
    echo "
    [erase-install] by @GrahamRPugh

    Common usage:
    [sudo] ./erase-install.sh [--list]  [--overwrite] [--move] [--path /path/to]
                [--build XYZ] [--os X.Y] [--version X.Y.Z] [--samebuild] [--sameos] 
                [--update] [--beta] [--seedprogram ...] [--erase] [--reinstall]
                [--test-run] [--current-user]

    [no flags]          Finds latest current production, non-forked version
                        of macOS, downloads it.
    --force-curl        Force the download of installinstallmacos.py from GitHub every run
                        regardless of whether there is already a copy on the system. 
                        Ensures that you are using the latest version.
    --no-curl           Prevents the download of installinstallmacos.py in case your 
                        security team don't like it.
    --list              List available updates only using installinstallmacos 
                        (don't download anything)
    --seedprogram ...   Select a non-standard seed program
    --catalogurl ...    Select a non-standard catalog URL (overrides seedprogram)
    --samebuild         Finds the build of macOS that matches the
                        existing system version, downloads it.
    --sameos            Finds the version of macOS that matches the
                        existing system version, downloads it.
    --os X.Y            Finds a specific inputted OS version of macOS if available
                        and downloads it if so. Will choose the latest matching build.
    --version X.Y.Z     Finds a specific inputted minor version of macOS if available
                        and downloads it if so. Will choose the latest matching build.
    --build XYZ         Finds a specific inputted build of macOS if available
                        and downloads it if so.
    --update            Checks that an existing installer on the system is still current, 
                        if not, it will delete it and download the current installer.
    --replace-invalid   Checks that an existing installer on the system is still valid
                        i.e. would successfully build on this system. If not, deletes it
                        and downloads the current installer.
    --move              If not erasing, moves the
                        downloaded macOS installer to $installer_directory
    --path /path/to     Overrides the destination of --move to a specified directory
    --erase             After download, erases the current system
                        and reinstalls macOS.
    --confirm           Displays a confirmation dialog prior to erasing the current
                        system and reinstalling macOS. Only applicable with
                        --erase argument.
    --depnotify         Uses DEPNotify for dialogs instead of jamfHelper, if installed.
                        Only applicable with --reinstall and --erase arguments.
    --reinstall         After download, reinstalls macOS without erasing the
                        current system
    --overwrite         Download macOS installer even if an installer
                        already exists in $installer_directory
    --extras /path/to   Overrides the path to search for extra packages
    --beta              Include beta versions in the search. Works with the no-flag
                        (i.e. automatic), --os and --version arguments.
    --check-power       Checks for AC power if set.
    --power-wait-limit NN
                        Maximum seconds to wait for detection of AC power, if 
                        --check-power is set. Default is 60.
                      

    Parameters for use with Apple Silicon Mac:
      Note that startosinstall requires user authentication on AS Mac. The user 
      must have a Secure Token. This script checks for the Secure Token of the 
      supplied user. An osascript dialog is used to supply the password, so
      this script cannot be run at the login window or from remote terminal.
    --current-user      Authenticate startosinstall using the current user
    --user XYZ          Supply a user with which to authenticate startosinstall

    Experimental features for macOS 10.15+:
    --list-full-installers
                        List installers using 'softwareupdate --list-full-installers'
    --fetch-full-installer
                        For compatible computers (10.15+) obtain the installer using
                        'softwareupdate --fetch-full-installer' method instead of
                        using installinstallmacos.py

    Experimental features for macOS 11+:
    --pkg               Downloads a package installer rather than the installer app.
                        Can be used with the --reinstall and --erase options.

    Note: If existing installer is found, this script will not check
          to see if it matches the installed system version. It will
          only check whether it is a valid installer. If you need to
          ensure that the currently installed version of macOS is used
          to wipe the device, use one of the --overwrite, --update or 
          --replace-invalid parameters.

    Parameters useful in testing this script:
    --test-run          Run through the script right to the end, but do not actually
                        run the 'startosinstall' command. The command that would be 
                        run is shown in stdout.
    --no-fs             Replaces the full-screen jamfHelper window with a smaller dialog,
                        so you can still access the desktop while the script runs.
    --no-jamfhelper     Ignores a jamfHelper installation, so that you can test (or use)
                        osascript dialogs.
    --min-drive-space   override the default minimum space required for startosinstall
                        to run (45 GB).
    --pythonpath /path/to
                        Supply a path to a different python binary.
                        Only relevant if using a mode that involves installinstallmacos.py
    --workdir /path/to  Supply an alternative working directory. The default is the same 
                        directory in which erase-install.sh is saved.

    "
    exit
}


# Main body

# Safety mechanism to prevent unwanted wipe while testing
erase="no"
reinstall="no"

# default minimum drive space in GB
min_drive_space=45

while test $# -gt 0
do
    case "$1" in
        -l|--list) list="yes"
            ;;
        -lfi|--list-full-installers) list_installers="yes"
            ;;
        -e|--erase) erase="yes"
            ;;
        -r|--reinstall) reinstall="yes"
            ;;
        -m|--move) move="yes"
            ;;
        -s|--samebuild) samebuild="yes"
            ;;
        -t|--sameos) sameos="yes"
            ;;
        -o|--overwrite) overwrite="yes"
            ;;
        -x|--replace-invalid) replace_invalid_installer="yes"
            ;;
        -u|--update) update_installer="yes"
            ;;
        -c|--confirm) confirm="yes"
            ;;
        --beta) beta="yes"
            ;;
        --preservecontainer) preservecontainer="yes"
            ;;
        -f|--fetch-full-installer) ffi="yes"
            ;;
        --pkg) pkg_installer="yes"
            ;;
        --keep-pkg) keep_pkg="yes"
            ;;
        --force-curl) force_installinstallmacos="yes"
            ;;
        --no-curl) no_curl="yes"
            ;;
        --no-fs) no_fs="yes"
            ;;
        --skip-validation) skip_validation="yes"
            ;;
        --current-user) use_current_user="yes"
            ;;
        --user) account_shortname="yes"
            ;;
        --test-run) test_run="yes"
            ;;
        --depnotify) 
            if [[ -d "$DEP_NOTIFY_APP" ]]; then
                use_depnotify="yes"
                dep_notify_quit
            fi
            ;;
        --no-jamfhelper) jamfHelper=""
            ;;
        --check-power) 
            check_power="yes"
            ;;
        --power-wait-limit) 
            shift
            power_wait_timer="$1"
            ;;
        --min-drive-space) 
            shift
            min_drive_space="$1"
            ;;
        --seedprogram)
            shift
            seedprogram="$1"
            ;;
        --catalogurl)
            shift
            catalogurl="$1"
            ;;
        --path)
            shift
            installer_directory="$1"
            ;;
        --pythonpath)
            shift
            python_path="$1"
            ;;
        --extras)
            shift
            extras_directory="$1"
            ;;
        --os)
            shift
            prechosen_os="$1"
            ;;
        --version)
            shift
            prechosen_version="$1"
            ;;
        --build)
            shift
            prechosen_build="$1"
            ;;
        --workdir)
            shift
            workdir="$1"
            ;;
        --power-wait-limit*)
            power_wait_timer=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --min-drive-space*)
            min_drive_space=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --seedprogram*)
            seedprogram=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --catalogurl*)
            catalogurl=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --path*)
            installer_directory=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --pythonpath*)
            python_path=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --extras*)
            extras_directory=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --os*)
            prechosen_os=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --version*)
            prechosen_version=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --build*)
            prechosen_build=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --workdir*)
            workdir=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        -h|--help) show_help
            ;;
    esac
    shift
done

echo
echo "   [erase-install] v$version script execution started: $(date)"

# if getting a list from softwareupdate then we don't need to make any OS checks
if [[ $list_installers ]]; then
    list_full_installers
    echo
    exit
fi

# ensure computer does not go to sleep while running this script
pid=$$
echo "   [erase-install] Caffeinating this script (pid=$pid)"
/usr/bin/caffeinate -dimsu -w $pid &
caffeinate_pid=$!

# not giving an option for fetch-full-installer mode for now... /Applications is the path
if [[ $ffi ]]; then
    installer_directory="/Applications"
fi

# ensure installer_directory exists
/bin/mkdir -p "$installer_directory"

# variable to prevent installinstallmacos getting downloaded twice
iim_downloaded=0

# some options vary based on installer versions
system_version=$( /usr/bin/sw_vers -productVersion )
system_os_major=$( echo "$system_version" | cut -d '.' -f 1 )
system_os_version=$( echo "$system_version" | cut -d '.' -f 2 )

# check for power and drive space if invoking erase or reinstall options
if [[ $erase == "yes" || $reinstall == "yes" ]]; then
    free_space_check
    [[ "$check_power" == "yes" ]] && check_power_status
fi

# Look for the installer, download it if it is not present
echo "   [erase-install] Looking for existing installer"
find_existing_installer

if [[ $invalid_installer_found == "yes" && -d "$install_macos_app" && $replace_invalid_installer == "yes" ]]; then
    overwrite_existing_installer
elif [[ $invalid_installer_found == "yes" && ($pkg_installer && ! -f "$installassistant_pkg") && $replace_invalid_installer == "yes" ]]; then
    echo "   [erase-install] Deleting invalid installer package"
    rm -f "$install_macos_app"
elif [[ $update_installer == "yes" && -d "$install_macos_app" && $overwrite != "yes" ]]; then
    echo "   [erase-install] Checking for newer installer"
    check_newer_available
    if [[ $newer_build_found == "yes" ]]; then 
        echo "   [erase-install] Newer installer found so overwriting existing installer"
        overwrite_existing_installer
    fi
elif [[ $update_installer == "yes" && ($pkg_installer && -f "$installassistant_pkg") && $overwrite != "yes" ]]; then
    echo "   [erase-install] Checking for newer installer"
    check_newer_available
    if [[ $newer_build_found == "yes" ]]; then 
        echo "   [erase-install] Newer installer found so deleting existing installer package"
        rm -f "$install_macos_app"
    fi
elif [[ $overwrite == "yes" && -d "$install_macos_app" && ! $list ]]; then
    overwrite_existing_installer
elif [[ $overwrite == "yes" && ($pkg_installer && -f "$installassistant_pkg") && ! $list ]]; then
    echo "   [erase-install] Deleting invalid installer package"
    rm -f "$installassistant_pkg"
elif [[ $invalid_installer_found == "yes" && ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]]; then
    echo "   [erase-install] ERROR: Invalid installer is present. Run with --overwrite option to ensure that a valid installer is obtained."
    exit 1
fi

# Silicon Macs require a username and password to run startosinstall
# We therefore need to be logged in to proceed, if we are going to erase or reinstall
# This goes before the download so users aren't waiting for the prompt for username
arch=$(/usr/bin/arch)
if [[ "$arch" == "arm64" && ($erase == "yes" || $reinstall == "yes") ]]; then
    if ! pgrep -q Finder ; then
        echo "    [erase-install] ERROR! The startosinstall binary requires a user to be logged in."
        echo
        exit 1
    fi
    get_user_details
fi

if [[ (! -d "$install_macos_app" && ! -f "$installassistant_pkg") || $list ]]; then
    echo "   [erase-install] Starting download process"
    # if erasing or reinstalling, open a dialog to state that the download is taking place.
    if [[ $erase == "yes" || $reinstall == "yes" ]]; then
        if [[ $use_depnotify == "yes" ]]; then
            echo "   [erase-install] Opening DEPNotify download message (language=$user_language)"
            dn_title="${!dialog_dl_title}"
            dn_desc="${!dialog_dl_desc}"
            dn_status="${!dialog_dl_title}"
            dn_icon="$dialog_dl_icon"
            dep_notify
        elif [[ -f "$jamfHelper" ]]; then
            echo "   [erase-install] Opening jamfHelper download message (language=$user_language)"
            "$jamfHelper" -windowType hud -windowPosition ul -title "${!dialog_dl_title}" -alignHeading center -alignDescription left -description "${!dialog_dl_desc}" -lockHUD -icon  "$dialog_dl_icon" -iconSize 100 &
        else
            echo "   [erase-install] Opening osascript dialog (language=$user_language)"
            /usr/bin/osascript -e "display alert \"${!dialog_dl_title}\" message \"${!dialog_dl_desc}\" buttons {\"OK\"} default button \"OK\" with icon 2"
        fi
    fi

    # now run installinstallmacos or softwareupdate
    if [[ $ffi ]]; then
        if [[ ($system_os_major -eq 10 && $system_os_version -ge 15) || $system_os_major -ge 11 ]]; then
            echo "   [erase-install] OS version is $system_os_major.$system_os_version so can run with --fetch-full-installer option"
            run_fetch_full_installer
        else
            echo "   [erase-install] OS version is $system_os_major.$system_os_version so cannot run with --fetch-full-installer option. Falling back to installinstallmacos.py"
            run_installinstallmacos
        fi
    else
        run_installinstallmacos
    fi
    # Once finished downloading, kill the jamfHelper
    if [[ $use_depnotify == "yes" ]]; then
        echo "   [erase-install] Closing DEPNotify download message (language=$user_language)"
        dn_finished="Download complete!" # TODO localize this message
        dep_notify_quit
    elif [[ -f "$jamfHelper" ]]; then
        echo "   [erase-install] Closing jamfHelper download message (language=$user_language)"
        kill_process "jamfHelper"
    fi
fi

if [[ $erase != "yes" && $reinstall != "yes" ]]; then
    if [[ -d "$install_macos_app" ]]; then
        echo "   [erase-install] Installer is at: $install_macos_app"
    fi

    # Move to $installer_directory if move_to_applications_folder flag is included
    # Not allowed for fetch_full_installer option
    if [[ $move == "yes" && ! $ffi ]]; then
        echo "   [erase-install] Invoking --move option"
        move_to_applications_folder
    fi

    # Unmount the dmg
    if [[ ! $ffi ]]; then
        existing_installer=$(find /Volumes/*macOS* -maxdepth 2 -type d -name "Install*.app" -print -quit 2>/dev/null )
        if [[ -d "$existing_installer" ]]; then
            echo "   [erase-install] Mounted installer will be unmounted: $existing_installer"
            existing_installer_mount_point=$(echo "$existing_installer" | cut -d/ -f 1-3)
            diskutil unmount force "$existing_installer_mount_point"
        fi
    fi
    # Clear the working directory
    echo "   [erase-install] Cleaning working directory '$workdir/content'"
    rm -rf "$workdir/content"
    # kill caffeinate
    kill_process "caffeinate"
    echo
    exit
fi

## Steps beyond here are to run startosinstall

echo
if [[ ! -d "$install_macos_app" ]]; then
    echo "   [erase-install] ERROR: Can't find the installer! "
    exit 1
fi
[[ $erase == "yes" ]] && echo "   [erase-install] WARNING! Running $install_macos_app with eraseinstall option"
[[ $reinstall == "yes" ]] && echo "   [erase-install] WARNING! Running $install_macos_app with reinstall option"
echo

# If configured to do so, display a confirmation window to the user. Note: default button is cancel
if [[ $confirm == "yes" ]]; then
    if [[ $erase == "yes" ]]; then
        if [[ $use_depnotify == "yes" ]]; then
            # DEPNotify dialog option
            echo "   [erase-install] Opening DEPNotify confirmation message (language=$user_language)"
            dn_title="${!dialog_confirmation_title}"
            dn_desc="${!dialog_confirmation_desc}"
            dn_status="${!dialog_confirmation_status}"
            dn_icon="$dialog_confirmation_icon"
            dn_button="${!dialog_confirmation_button}"
            dn_quit_key="c"
            dep_notify
            dn_pid=$(pgrep -l "DEPNotify" | cut -d " " -f1)
            # wait for the confirmation button to be pressed or for the user to cancel
            until [[ "$dn_pid" = "" ]]; do
                sleep 1
                dn_pid=$(pgrep -l "DEPNotify" | cut -d " " -f1)
            done
            # DEPNotify creates a bom file if the user presses the confirmation button
            # but not if they cancel
            if [[ -f "$DEP_NOTIFY_CONFIRMATION_FILE" ]]; then
                confirmation=2
            else
                confirmation=0
            fi
            # now clear the button, quit key and dialog
            dep_notify_quit
        elif [[ -f "$jamfHelper" ]]; then
            # jamfHelper dialog option
            echo "   [erase-install] Opening jamfHelper confirmation message (language=$user_language)"
            "$jamfHelper" -windowType utility -title "${!dialog_confirmation_title}" -alignHeading center -alignDescription natural -description "${!dialog_confirmation_desc}" -lockHUD -icon "$dialog_confirmation_icon" -button1 "${!dialog_cancel_button}" -button2 "${!dialog_confirmation_button}" -defaultButton 1 -cancelButton 1 2> /dev/null
            confirmation=$?
        else
            # osascript dialog option
            echo "   [erase-install] Opening osascript dialog for confirmation (language=$user_language)"
            answer=$(
                /usr/bin/osascript <<-END
                    set nameentry to button returned of (display dialog "${!dialog_confirmation_desc}" buttons {"${!dialog_confirmation_button}", "${!dialog_cancel_button}"} default button "${!dialog_cancel_button}" with icon 2)
END
)
            if [[ "$answer" == "${!dialog_confirmation_button}" ]]; then
                confirmation=2
            else
                confirmation=0
            fi
        fi
        if [[ "$confirmation" == "0"* ]]; then
            echo "   [erase-install] User DECLINED erase/install"
            exit 0
        elif [[ "$confirmation" == "2"* ]]; then
            echo "   [erase-install] User CONFIRMED erase/install"
        else
            echo "   [erase-install] User FAILED to confirm erase/install"
            exit 1
        fi
    else
        echo "   [erase-install] --confirm requires --erase argument; ignoring"
    fi
fi

# determine SIP status, as the volume is required if SIP is disabled
/usr/bin/csrutil status | grep -q 'disabled' && sip="disabled" || sip="enabled"

# set install argument for erase option
install_args=()
if [[ $erase == "yes" ]]; then
    install_args+=("--eraseinstall")
elif [[ $reinstall == "yes" && $sip == "disabled" ]]; then
    volname=$(diskutil info -plist / | grep -A1 "VolumeName" | tail -n 1 | awk -F '<string>|</string>' '{ print $2; exit; }')
    install_args+=("--volume")
    install_args+=("/Volumes/$volname")
fi

# check for packages then add install_package_list to end of command line (empty if no packages found)
find_extra_packages

# some cli options vary based on installer versions
installer_build=$( /usr/bin/defaults read "$install_macos_app/Contents/Info.plist" DTSDKBuild )

# add --preservecontainer to the install arguments if specified (for macOS 10.14 (Darwin 18) and above)
if [[ ${installer_build:0:2} -gt 18 && $preservecontainer == "yes" ]]; then
    install_args+=("--preservecontainer")
fi

# OS X 10.12 (Darwin 16) requires the --applicationpath option
if [[ ${installer_build:0:2} -lt 17 ]]; then
    install_args+=("--applicationpath")
    install_args+=("$install_macos_app")
fi

# macOS 11 (Darwin 20) and above requires the --allowremoval option
if [[ ${installer_build:0:2} -eq 19 ]]; then
    install_args+=("--allowremoval")
fi

# macOS 10.15 (Darwin 19) and above requires the --forcequitapps options
if [[  ${installer_build:0:2} -ge 19 ]]; then    
    install_args+=("--forcequitapps")
fi

# icons for Jamf Helper erase and re-install windows
dialog_erase_icon="$install_macos_app/Contents/Resources/InstallAssistant.icns"
dialog_reinstall_icon="$install_macos_app/Contents/Resources/InstallAssistant.icns"

# if no_fs is set, show a utility window instead of the full screen display (for test purposes)
[[ $no_fs == "yes" ]] && window_type="utility" || window_type="fs"

# dialogs for reinstallation
if [[ $erase == "yes" ]]; then
    if [[ $use_depnotify == "yes" ]]; then
        echo "   [erase-install] Opening DEPNotify full screen message (language=$user_language)"
        dn_title="${!dialog_erase_title}"
        dn_desc="${!dialog_erase_desc}"
        dn_status="${!dialog_reinstall_status}"
        dn_icon="$dialog_erase_icon"
        dep_notify
        PID=$(pgrep -l "DEPNotify" | cut -d " " -f1)
    elif [[ -f "$jamfHelper" ]]; then
        echo "   [erase-install] Opening jamfHelper full screen message (language=$user_language)"
        "$jamfHelper" -windowType $window_type -title "${!dialog_erase_title}" -heading "${!dialog_erase_title}" -description "${!dialog_erase_desc}" -icon "$dialog_erase_icon" &
        PID=$!
    else
        echo "   [erase-install] Opening osascript dialog (language=$user_language)"
        /usr/bin/osascript <<-END &
            display dialog "${!dialog_erase_desc}" buttons {"OK"} default button "OK" with icon stop
END
        PID=$!
    fi

# dialogs for reinstallation
elif [[ $reinstall == "yes" ]]; then
    if [[ $use_depnotify == "yes" ]]; then
        echo "   [erase-install] Opening DEPNotify full screen message (language=$user_language)"
        dn_title="${!dialog_reinstall_title}"
        dn_desc="${!dialog_reinstall_desc}"
        dn_status="${!dialog_reinstall_status}"
        dn_icon="$dialog_reinstall_icon"
        dep_notify
        PID=$(pgrep -l "DEPNotify" | cut -d " " -f1)
    elif [[ -f "$jamfHelper" ]]; then
        echo "   [erase-install] Opening jamfHelper full screen message (language=$user_language)"
        "$jamfHelper" -windowType $window_type -title "${!dialog_reinstall_title}" -heading "${!dialog_reinstall_heading}" -description "${!dialog_reinstall_desc}" -icon "$dialog_reinstall_icon" &
        PID=$!
    else
        echo "   [erase-install] Opening osascript dialog (language=$user_language)"
        /usr/bin/osascript <<-END &
            display dialog "${!dialog_reinstall_desc}" buttons {"OK"} default button "OK" with icon stop
END
        PID=$!
    fi
fi

# run it!
if [[ $test_run != "yes" ]]; then
    if [ "$arch" == "arm64" ]; then
        # startosinstall --eraseinstall may fail if a user was converted to admin using the Privileges app
        # this command supposedly fixes this problem (experimental!)
        if [[ "$erase" == "yes" ]]; then
            echo  "   [get_user_details] updating preboot files (takes a few seconds)..."
            /usr/sbin/diskutil apfs updatepreboot / > /dev/null
        fi        
        # shellcheck disable=SC2086
        "$install_macos_app/Contents/Resources/startosinstall" "${install_args[@]}" --pidtosignal $PID --agreetolicense --nointeraction --stdinpass --user "$account_shortname" "${install_package_list[@]}" <<< $account_password
    else
        "$install_macos_app/Contents/Resources/startosinstall" "${install_args[@]}" --pidtosignal $PID --agreetolicense --nointeraction "${install_package_list[@]}"
    fi
    # kill Self Service if running
    kill_process "Self Service"
else
    echo "   [erase-install] Run without '--test-run' to run this command:"
    if [ "$arch" == "arm64" ]; then
        echo "$install_macos_app/Contents/Resources/startosinstall" "${install_args[@]}" "--pidtosignal $PID --pidtosignal $caffeinate_pid --agreetolicense --nointeraction --stdinpass --user" "$account_shortname" "${install_package_list[@]}" "<<< [PASSWORD REDACTED]"
    else
        echo "$install_macos_app/Contents/Resources/startosinstall" "${install_args[@]}" --pidtosignal $PID --pidtosignal $caffeinate_pid --agreetolicense --nointeraction "${install_package_list[@]}"
    fi
    sleep 120
fi

# kill any dialogs if startosinstall ends before a reboot
kill_process "jamfHelper"
dep_notify_quit

# kill caffeinate
kill_process "caffeinate"

# if we get this far and we promoted the user then we should demote it again
if [[ $promoted_user ]]; then
    /usr/sbin/dseditgroup -o edit -d "$promoted_user" admin
    echo "     [erase-install] User $promoted_user was demoted back to standard user"
fi
