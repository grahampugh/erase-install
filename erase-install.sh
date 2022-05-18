#!/bin/bash

# shellcheck disable=SC2001
# this is to use sed in the case statements
# shellcheck disable=SC2034
# this is due to the dynamic variable assignments used in the localization strings

:<<DOC
erase-install.sh
by Graham Pugh

WARNING. This is a self-destruct script. Do not try it out on your own device!

See README.md and the GitHub repo's Wiki for details on use.

It is recommended to use the package installer of this script. It contains the bundled
installinstallmacos.py fork, plus a relocatable python with which to run it.

This script can, however, also be run standalone.
It will download and install the MacAdmins Python Framework if not found.
It will also download the installinstallmacos.py fork if it is not found.
Suppress the downloads with the --no-curl option.

Requirements:
- macOS 12.4+
- macOS 10.13.4+ (for --erase option)
- macOS 10.15+ (for --fetch-full-installer option)
- Device file system is APFS

Original version of installinstallmacos.py - Greg Neagle; GitHub munki/macadmins-scripts
DOC

###############
## VARIABLES ##
###############

# script name
script_name="erase-install"

# Version of this script
version="26.1"

# URL for downloading installinstallmacos.py
installinstallmacos_url="https://raw.githubusercontent.com/grahampugh/macadmin-scripts/v${version}/installinstallmacos.py"
installinstallmacos_checksum="bb21421f277090a0fe163815796058313859633804fc992a07e8b4cc9779d0cf"

# Directory in which to place the macOS installer. Overridden with --path
installer_directory="/Applications"

# Default working directory (may be overridden by the --workdir parameter)
workdir="/Library/Management/erase-install"

# URL for downloading macadmins python (with tag version) for standalone script running
macadmins_python_version="v3.10.2.80694"
macadmins_python_url="https://api.github.com/repos/macadmins/python/releases/tags/$macadmins_python_version"
macadmins_python_path="/Library/ManagedFrameworks/Python/Python3.framework/Versions/Current/bin/python3"

# Dialog helper apps
jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
depnotify_app="/Applications/Utilities/DEPNotify.app"
depnotify_log="/var/tmp/depnotify.log"
depnotify_confirmation_file="/var/tmp/com.depnotify.provisioning.done"
depnotify_download_url="https://files.nomad.menu/DEPNotify.pkg"


###################
## LOCALIZATIONS ##
###################

# Grab currently logged in user to set the language for Dialogue messages
current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
current_uid=$(/usr/bin/id -u "$current_user")
# Get proper home directory. Output of scutil might not reflect the canonical RecordName or the HomeDirectory at all, which might prevent us from detecting the language
current_user_homedir=$(/usr/libexec/PlistBuddy -c 'Print :dsAttrTypeStandard\:NFSHomeDirectory:0' /dev/stdin <<< "$(/usr/bin/dscl -plist /Search -read "/Users/${current_user}" NFSHomeDirectory)")
language=$(/usr/libexec/PlistBuddy -c 'print AppleLanguages:0' "/${current_user_homedir}/Library/Preferences/.GlobalPreferences.plist")
if [[ $language = de* ]]; then
    user_language="de"
elif [[ $language = nl* ]]; then
    user_language="nl"
elif [[ $language = fr* ]]; then
    user_language="fr"
else
    user_language="en"
fi

# Dialogue localizations - download window
dialog_dl_title_en="Downloading macOS"
dialog_dl_title_de="macOS wird heruntergeladen"
dialog_dl_title_nl="macOS downloaden"
dialog_dl_title_fr="Téléchargement de macOS"

dialog_dl_desc_en="We need to download the macOS installer to your computer; this will take several minutes."
dialog_dl_desc_de="Der macOS Installer wird heruntergeladen, dies dauert mehrere Minuten."
dialog_dl_desc_nl="We moeten het macOS besturingssysteem downloaden, dit duurt enkele minuten."
dialog_dl_desc_fr="Nous devons télécharger le programme d'installation de macOS sur votre ordinateur, cela prendra plusieurs minutes."

# Dialogue localizations - erase lockscreen
dialog_erase_title_en="Erasing macOS"
dialog_erase_title_de="macOS wiederherstellen"
dialog_erase_title_nl="macOS herinstalleren"
dialog_erase_title_fr="Effacement de macOS"

dialog_erase_desc_en="Preparing the installer may take up to 30 minutes. Once completed your computer will reboot and continue the reinstallation."
dialog_erase_desc_de="Das Vorbereiten des Installationsprogramms kann bis zu 30 Minuten dauern. Nach Abschluss wird Ihr Computer neu gestartet und die Neuinstallation fortgesetzt."
dialog_erase_desc_nl="Het voorbereiden van het installatieprogramma kan tot 30 minuten duren. Zodra het proces is voltooid, wordt uw computer opnieuw opgestart en wordt de herinstallatie voortgezet."
dialog_erase_desc_fr="La préparation de l'installation peut prendre jusqu'à 30 minutes. Une fois terminée, votre ordinateur redémarrera et poursuivra la réinstallation."

# Dialogue localizations - reinstall lockscreen
dialog_reinstall_title_en="Upgrading macOS"
dialog_reinstall_title_de="Upgrading macOS"
dialog_reinstall_title_nl="macOS upgraden"
dialog_reinstall_title_fr="Mise à niveau de macOS"

dialog_reinstall_heading_en="Please wait as we prepare your computer for upgrading macOS."
dialog_reinstall_heading_de="Bitte warten, das Upgrade macOS wird ausgeführt."
dialog_reinstall_heading_nl="Even geduld terwijl we uw computer voorbereiden voor de upgrade van macOS."
dialog_reinstall_heading_fr="Veuillez patienter pendant que nous préparons votre ordinateur pour la mise à niveau de macOS."

dialog_reinstall_desc_en="This process may take up to 30 minutes. Once completed your computer will reboot and begin the upgrade."
dialog_reinstall_desc_de="Dieser Prozess benötigt bis zu 30 Minuten. Der Mac startet anschliessend neu und beginnt mit dem Update."
dialog_reinstall_desc_nl="Dit proces duurt ongeveer 30 minuten. Zodra dit is voltooid, wordt uw computer opnieuw opgestart en begint de upgrade."
dialog_reinstall_desc_fr="Ce processus peut prendre jusqu'à 30 minutes. Une fois terminé, votre ordinateur redémarrera et commencera la mise à niveau."

dialog_reinstall_status_en="Preparing macOS for installation"
dialog_reinstall_status_de="Vorbereiten von macOS für die Installation"
dialog_reinstall_status_nl="MacOS voorbereiden voor installatie"
dialog_reinstall_status_fr="Préparation de macOS pour l'installation"

dialog_rebooting_heading_en="The upgrade is now ready for installation. Please save your work!"
dialog_rebooting_heading_de="Das Upgrade ist nun bereit für die Installation. Bitte speichern Sie Ihre Arbeit!"
dialog_rebooting_heading_nl="De upgrade is nu klaar voor installatie. Sla uw werk op!"
dialog_rebooting_heading_fr="La mise à niveau est maintenant prête à être installée. Veuillez sauvegarder votre travail!"

dialog_rebooting_status_en="Preparation complete - restarting in"
dialog_rebooting_status_de="Vorbereitung abgeschlossen - Neustart in "
dialog_rebooting_status_nl="Voorbereiding compleet - herstart over"
dialog_rebooting_status_fr="Préparation terminée - redémarrage dans"

# Dialogue localizations - confirmation window (erase)
dialog_erase_confirmation_desc_en="Please confirm that you want to ERASE ALL DATA FROM THIS DEVICE and reinstall macOS"
dialog_erase_confirmation_desc_de="Bitte bestätigen, dass Sie ALLE DATEN VON DIESEM GERÄT LÖSCHEN und macOS neu installieren wollen"
dialog_erase_confirmation_desc_nl="Weet je zeker dat je ALLE GEGEVENS VAN DIT APPARAAT WILT WISSEN en macOS opnieuw installeert?"
dialog_erase_confirmation_desc_fr="Veuillez confirmer que vous souhaitez EFFACER TOUTES LES DONNÉES DE CET APPAREIL et réinstaller macOS"

# Dialogue localizations - confirmation window (reinstall)
dialog_reinstall_confirmation_desc_en="Please confirm that you want to upgrade macOS on this system now"
dialog_reinstall_confirmation_desc_de="Bitte bestätigen Sie, dass Sie macOS auf diesem System jetzt aktualisieren möchten"
dialog_reinstall_confirmation_desc_nl="Bevestig dat u macOS op dit systeem nu wilt updaten"
dialog_reinstall_confirmation_desc_fr="Veuillez confirmer que vous voulez mettre à jour macOS sur ce système maintenant."

# Dialogue localizations - confirmation window status
dialog_confirmation_status_en="Press Cmd + Ctrl + C to Cancel"
dialog_confirmation_status_de="Drücken Sie Cmd + Ctrl + C zum Abbrechen"
dialog_confirmation_status_nl="Druk op Cmd + Ctrl + C om te Annuleren"
dialog_confirmation_status_fr="Appuyez sur Cmd + Ctrl + C pour annuler"

# Dialogue buttons
dialog_confirmation_button_en="Confirm"
dialog_confirmation_button_de="Bestätigen"
dialog_confirmation_button_nl="Bevestig"
dialog_confirmation_button_fr="Confirmer"

dialog_cancel_button_en="Stop"
dialog_cancel_button_de="Abbrechen"
dialog_cancel_button_nl="Annuleren"
dialog_cancel_button_fr="Annuler"

dialog_enter_button_en="Enter"
dialog_enter_button_de="Eingeben"
dialog_enter_button_nl="Enter"
dialog_enter_button_fr="Entrer"

# Dialogue localizations - free space check
dialog_check_desc_en="The macOS upgrade cannot be installed as there is not enough space left on the drive."
dialog_check_desc_de="Das Upgrade von macOS kann nicht installiert werden, da nicht genügend Speicherplatz auf dem Laufwerk vorhanden ist."
dialog_check_desc_nl="De upgrade van macOS kan niet worden geïnstalleerd omdat er niet genoeg ruimte is op de schijf."
dialog_check_desc_fr="La mise à niveau de macOS ne peut pas être installée car il n'y a pas assez d'espace disponible sur ce volume."

# Dialogue localizations - power check
dialog_power_title_en="Waiting for AC Power Connection"
dialog_power_title_de="Warten auf AC-Netzteil"
dialog_power_title_nl="Wachten op stroomadapter"
dialog_power_title_fr="En attente de l'alimentation secteur"

dialog_power_desc_en="Please connect your computer to power using an AC power adapter. This process will continue if AC power is detected within the next:"
dialog_power_desc_de="Bitte schließen Sie Ihren Computer mit einem AC-Netzteil an das Stromnetz an. Dieser Prozess wird fortgesetzt, sobald die AC-Stromversorgung innerhalb der folgende Zeitdauer erkannt wird:"
dialog_power_desc_nl="Sluit uw computer aan met de stroomadapter. Zodra deze is gedetecteerd gaat het proces verder binnen de volgende:"
dialog_power_desc_fr="Veuillez connecter votre ordinateur à un adaptateur secteur. Ce processus se poursuivra une fois que l'alimentation secteur sera détectée dans la suivante:"

dialog_nopower_desc_en="Exiting. AC power was not connected after waiting for:"
dialog_nopower_desc_de="Beenden. Die Stromversorgung wurde nach einer Wartezeit nicht hergestellt:"
dialog_nopower_desc_nl="Afsluiten. De wisselstroom was niet aangesloten na het wachten op:"
dialog_nopower_desc_fr="Sortie. Le courant alternatif n'a pas été connecté après avoir attendu:"

# Dialogue localizations - ask for short name
dialog_short_name_en="Please enter an account name to start the reinstallation process"
dialog_short_name_de="Bitte geben Sie einen Kontonamen ein, um die Neuinstallation zu starten"
dialog_short_name_nl="Voer een accountnaam in om het installatieproces te starten"
dialog_short_name_fr="Veuillez entrer un nom de compte pour démarrer le processus de réinstallation"

# Dialogue localizations - ask for password
dialog_not_volume_owner_en="Account is not a Volume Owner! Please login using one of the following accounts and try again"
dialog_not_volume_owner_de="Konto ist kein Volume-Besitzer! Bitte melden Sie sich mit einem der folgenden Konten an und versuchen Sie es erneut"
dialog_not_volume_owner_nl="Account is geen volume-eigenaar! Log in met een van de volgende accounts en probeer het opnieuw"
dialog_not_volume_owner_fr="Le compte n'est pas propriétaire du volume! Veuillez vous connecter en utilisant l'un des comptes suivants et réessayer"

# Dialogue localizations - invalid user
dialog_user_invalid_en="This account cannot be used to to perform the reinstall"
dialog_user_invalid_de="Dieses Konto kann nicht zur Durchführung der Neuinstallation verwendet werden"
dialog_user_invalid_nl="Dit account kan niet worden gebruikt om de herinstallatie uit te voeren"
dialog_user_invalid_fr="Ce compte ne peut pas être utilisé pour effectuer la réinstallation"

# Dialogue localizations - invalid password
dialog_invalid_password_en="ERROR: The password entered is NOT the login password for"
dialog_invalid_password_de="ERROR: Das eingegebene Passwort ist NICHT das Anmeldepasswort für"
dialog_invalid_password_nl="FOUT: Het ingevoerde wachtwoord is NIET het inlogwachtwoord voor"
dialog_invalid_password_fr="ERREUR : Le mot de passe entré n'est PAS le mot de passe de connexion pour"

# Dialogue localizations - not a volume owner
dialog_get_password_en="Please enter the password for the account"
dialog_get_password_de="Bitte geben Sie das Passwort für das Konto ein"
dialog_get_password_nl="Voer het wachtwoord voor het account in"
dialog_get_password_fr="Veuillez saisir le mot de passe du compte"

# icon for download window
dialog_dl_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/SidebarDownloadsFolder.icns"

# icon for confirmation dialog
dialog_confirmation_icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

# set localisation variables
dialog_dl_title=dialog_dl_title_${user_language}
dialog_dl_desc=dialog_dl_desc_${user_language}
dialog_erase_title=dialog_erase_title_${user_language}
dialog_erase_desc=dialog_erase_desc_${user_language}
dialog_reinstall_title=dialog_reinstall_title_${user_language}
dialog_reinstall_heading=dialog_reinstall_heading_${user_language}
dialog_reinstall_desc=dialog_reinstall_desc_${user_language}
dialog_reinstall_status=dialog_reinstall_status_${user_language}
dialog_rebooting_title=dialog_rebooting_title_${user_language}
dialog_rebooting_heading=dialog_rebooting_heading_${user_language}
dialog_rebooting_status=dialog_rebooting_status_${user_language}
dialog_erase_confirmation_title=dialog_erase_confirmation_title_${user_language}
dialog_erase_confirmation_desc=dialog_erase_confirmation_desc_${user_language}
dialog_confirmation_status=dialog_confirmation_status_${user_language}
dialog_confirmation_button=dialog_confirmation_button_${user_language}
dialog_reinstall_confirmation_title=dialog_reinstall_confirmation_title_${user_language}
dialog_reinstall_confirmation_desc=dialog_reinstall_confirmation_desc_${user_language}
dialog_cancel_button=dialog_cancel_button_${user_language}
dialog_enter_button=dialog_enter_button_${user_language}
dialog_check_desc=dialog_check_desc_${user_language}
dialog_power_desc=dialog_power_desc_${user_language}
dialog_nopower_desc=dialog_nopower_desc_${user_language}
dialog_power_title=dialog_power_title_${user_language}
dialog_short_name=dialog_short_name_${user_language}
dialog_user_invalid=dialog_user_invalid_${user_language}
dialog_get_password=dialog_get_password_${user_language}
dialog_invalid_password=dialog_invalid_password_${user_language}
dialog_not_volume_owner=dialog_not_volume_owner_${user_language}


###############
## FUNCTIONS ##
###############

ask_for_password() {
    # required for Silicon Macs
    if [[ $max_password_attempts == "infinite" ]]; then
        /bin/launchctl asuser "$current_uid" /usr/bin/osascript <<END
        set nameentry to text returned of (display dialog "${!dialog_get_password} ($account_shortname)" default answer "" with hidden answer buttons {"${!dialog_enter_button}"} default button 1 with icon 2)
END
    else
        /bin/launchctl asuser "$current_uid" /usr/bin/osascript <<END
        set nameentry to text returned of (display dialog "${!dialog_get_password} ($account_shortname)" default answer "" with hidden answer buttons {"${!dialog_enter_button}", "${!dialog_cancel_button}"} default button 1 with icon 2)
END
    fi
}

ask_for_shortname() {
    # required for Silicon Macs
    /bin/launchctl asuser "$current_uid" /usr/bin/osascript <<END
        set nameentry to text returned of (display dialog "${!dialog_short_name}" default answer "" buttons {"${!dialog_enter_button}", "${!dialog_cancel_button}"} default button 1 with icon 2)
END
}

check_free_space() {
    # determine if the amount of free and purgable drive space is sufficient for the upgrade to take place.
    free_disk_space=$(osascript -l 'JavaScript' -e "ObjC.import('Foundation'); var freeSpaceBytesRef=Ref(); $.NSURL.fileURLWithPath('/').getResourceValueForKeyError(freeSpaceBytesRef, 'NSURLVolumeAvailableCapacityForImportantUsageKey', null); Math.round(ObjC.unwrap(freeSpaceBytesRef[0]) / 1000000000)")  # with thanks to Pico

    if [[ -z "$current_user" ]]; then
        # fall back to df -h if the above fails
        free_disk_space=$(df -Pk . | column -t | sed 1d | awk '{print $4}')
    fi
    
    if [[ $free_disk_space -ge $min_drive_space ]]; then
        echo "   [check_free_space] OK - $free_disk_space GB free/purgeable disk space detected"
    else
        echo "   [check_free_space] ERROR - $free_disk_space GB free/purgeable disk space detected"
        if [[ -f "$jamfHelper" ]]; then
            "$jamfHelper" -windowType "utility" -description "${!dialog_check_desc}" -alignDescription "left" -icon "$dialog_confirmation_icon" -button1 "OK" -defaultButton "0" -cancelButton "1"
        else
            # open_osascript_dialog syntax: title, message, button1, icon
            open_osascript_dialog "${!dialog_check_desc}" "" "OK" stop &
        fi
        exit 1
    fi
}

check_installer_pkg_is_valid() {
    # check InstallAssistant pkg validity
    # packages generated by installinstallmacos.py have the format InstallAssistant-version-build.pkg
    # Extracting an actual version from the package is slow as the entire package must be unpackaged
    # to read the PackageInfo file. 
    # We are here YOLOing the filename instead. Of course it could be spoofed, but that would not be
    # in anyone's interest to attempt as it will just make the script eventually fail.
    echo "   [check_installer_pkg_is_valid] Checking validity of $existing_installer_pkg."
    installer_pkg_build=$( basename "$existing_installer_pkg" | sed 's|.pkg||' | cut -d'-' -f 3 )
    system_build=$( /usr/bin/sw_vers -buildVersion )

    compare_build_versions "$system_build" "$installer_pkg_build"

    if [[ $first_build_newer == "yes" ]]; then
        echo "   [check_installer_pkg_is_valid] Installer: $installer_pkg_build < System: $system_build : invalid build."
        working_installer_pkg="$existing_installer_pkg"
        invalid_installer_found="yes"
    else
        echo "   [check_installer_pkg_is_valid] Installer: $installer_pkg_build >= System: $system_build : valid build."
        working_installer_pkg="$existing_installer_pkg"
        invalid_installer_found="no"
    fi

    working_macos_app="$existing_installer_app"
}

check_installer_is_valid() {
    # check installer validity:
    # The Build version in the app Info.plist is often older than the advertised build, 
    # so it's not a great check for validity
    # check if running --erase, where we might be using the same build.
    # The actual build number is found in the SharedSupport.dmg in com_apple_MobileAsset_MacSoftwareUpdate.xml (Big Sur and greater).
    # This is new from Big Sur, so we include a fallback to the Info.plist file just in case. 
    echo "   [check_installer_is_valid] Checking validity of $existing_installer_app."

    # first ensure that some earlier instance is not still mounted as it might interfere with the check
    [[ -d "/Volumes/Shared Support" ]] && diskutil unmount force "/Volumes/Shared Support"
    # now attempt to mount
    if [[ -f "$existing_installer_app/Contents/SharedSupport/SharedSupport.dmg" ]]; then
        if hdiutil attach -quiet -noverify -nobrowse "$existing_installer_app/Contents/SharedSupport/SharedSupport.dmg" ; then
            echo "   [check_installer_is_valid] Mounting $existing_installer_app/Contents/SharedSupport/SharedSupport.dmg"
            sleep 1
            build_xml="/Volumes/Shared Support/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
            if [[ -f "$build_xml" ]]; then
                echo "   [check_installer_is_valid] Using Build value from com_apple_MobileAsset_MacSoftwareUpdate.xml"
                installer_build=$(/usr/libexec/PlistBuddy -c "Print :Assets:0:Build" "$build_xml")
                sleep 1
                diskutil unmount force "/Volumes/Shared Support"
            else
                echo "   [check_installer_is_valid] ERROR: com_apple_MobileAsset_MacSoftwareUpdate.xml not found. Check the mount point at /Volumes/Shared Support"
            fi
        else
            echo "   [check_installer_is_valid] Mounting SharedSupport.dmg failed"
        fi
    else
        # if that fails, fallback to the method for 10.15 or less, which is less accurate
        echo "   [check_installer_is_valid] Using DTSDKBuild value from Info.plist"
        if [[ -f "$existing_installer_app/Contents/Info.plist" ]]; then
            installer_build=$( /usr/bin/defaults read "$existing_installer_app/Contents/Info.plist" DTSDKBuild )
        else
            echo "   [check_installer_is_valid] Installer Info.plist could not be found!"
        fi
    fi
    if [[ ! $installer_build ]]; then
        echo "   [check_installer_is_valid] Build of existing installer could not be found!"
        exit 1
    fi

    system_build=$( /usr/bin/sw_vers -buildVersion )

    compare_build_versions "$system_build" "$installer_build"
    if [[ $first_build_major_newer == "yes" || $first_build_minor_newer == "yes" ]]; then
        echo "   [check_installer_is_valid] Installer: $installer_build < System: $system_build : invalid build."
        invalid_installer_found="yes"
    elif [[ $first_build_patch_newer == "yes" ]]; then
        echo "   [check_installer_is_valid] Installer: $installer_build < System: $system_build : build might work but if it fails, please obtain a newer installer."
        warning_issued="yes"
        invalid_installer_found="no"
    else
        echo "   [check_installer_is_valid] Installer: $installer_build >= System: $system_build : valid build."
        invalid_installer_found="no"
    fi

    working_macos_app="$existing_installer_app"
}

check_newer_available() {
    # Download installinstallmacos.py and MacAdmins python
    get_installinstallmacos
    if [[ ! -f "$python_path" ]]; then
        get_relocatable_python
    fi

    # build arguments for installinstallmacos
    installinstallmacos_args=()
    installinstallmacos_args+=("--workdir")
    installinstallmacos_args+=("$workdir")
    installinstallmacos_args+=("--list")
    if [[ $catalogurl ]]; then
        echo "   [check_newer_available] Non-standard catalog URL selected"
        installinstallmacos_args+=("--catalogurl")
        installinstallmacos_args+=("$catalogurl")
    elif [[ $seedprogram ]]; then
        echo "   [check_newer_available] Non-standard seedprogram selected"
        installinstallmacos_args+=("--seed")
        installinstallmacos_args+=("$seedprogram")
    elif [[ $catalog ]]; then
        darwin_version=$(get_darwin_from_os_version "$catalog")
        echo "   [run_installinstallmacos] Non-default catalog selected (darwin version $darwin_version)"
        installinstallmacos_args+=("--catalog")
        installinstallmacos_args+=("$darwin_version")
    fi
    if [[ $beta == "yes" ]]; then
        echo "   [check_newer_available] Beta versions included"
        installinstallmacos_args+=("--beta")
    fi
    if [[ $pkg_installer ]]; then
        echo "   [check_newer_available] checking against package installers"
        installinstallmacos_args+=("--pkg")
    fi

    # run installinstallmacos.py with list and then interrogate the plist
    # TEST 
    echo
    echo "   [check_newer_available] This command is now being run:"
    echo
    echo "   installinstallmacos.py ${installinstallmacos_args[*]}"

    if "$python_path" "$workdir/installinstallmacos.py" "${installinstallmacos_args[@]}" > /dev/null; then
        i=0
        newer_build_found="no"
        if [[ -f "$workdir/softwareupdate.plist" ]]; then
            while available_build=$( /usr/libexec/PlistBuddy -c "Print :result:$i:build" "$workdir/softwareupdate.plist" 2>/dev/null); do
                compare_build_versions "$available_build" "$installer_build"
                if [[ "$first_build_newer" == "yes" ]]; then
                    newer_build_found="yes"
                fi
                i=$((i+1))
            done
        else
            echo "   [check_newer_available] ERROR reading output from installinstallmacos.py, cannot continue"
            exit 1
        fi
        [[ $newer_build_found != "yes" ]] && echo "   [check_newer_available] No newer builds found"
    else
        echo "   [check_newer_available] ERROR running installinstallmacos.py, cannot continue"
        exit 1
    fi
}

check_password() {
    # Check that the password entered matches actual password
    # required for Silicon Macs
    # thanks to Dan Snelson for the idea
    user="$1"
    password="$2"
    password_matches=$( /usr/bin/dscl /Search -authonly "$user" "$password" )

    if [[ -z "$password_matches" ]]; then
        echo "   [check_password] Success: the password entered is the correct login password for $user."
        password_check="pass"
    else
        echo "   [check_password] ERROR: The password entered is NOT the login password for $user."
        password_check="fail"
        /usr/bin/afplay "/System/Library/Sounds/Basso.aiff"
    fi
}

check_power_status() {
    # Check if device is on battery or AC power
    # If not, and our power_wait_timer is above 1, allow user to connect to power for specified time period
    # Acknowledgements: https://github.com/kc9wwh/macOSUpgrade/blob/master/macOSUpgrade.sh

    # default power_wait_timer to 60 seconds
    [[ ! $power_wait_timer ]] && power_wait_timer=60

    power_wait_timer_friendly=$( printf '%02dh:%02dm:%02ds\n' $((power_wait_timer/3600)) $((power_wait_timer%3600/60)) $((power_wait_timer%60)) )

    if /usr/bin/pmset -g ps | /usr/bin/grep "AC Power" > /dev/null ; then
        echo "   [check_power_status] OK - AC power detected"
    else
        echo "   [check_power_status] WARNING - No AC power detected"
        if [[ "$power_wait_timer" -gt 0 ]]; then
            if [[ -f "$jamfHelper" ]]; then
                # use jamfHelper if possible
                "$jamfHelper" -windowType "utility" -title "${!dialog_power_title}" -description "${!dialog_power_desc} ${power_wait_timer_friendly}" -alignDescription "left" -icon "$dialog_confirmation_icon" &
                wait_for_power "jamfHelper"
            else
                # open_osascript_dialog syntax: title, message, button1, icon
                open_osascript_dialog "${!dialog_power_desc}  ${power_wait_timer_friendly}" "" "OK" stop &
                wait_for_power "osascript"
            fi
        else
            echo "   [check_power_status] ERROR - No AC power detected after ${power_wait_timer_friendly}, cannot continue."
            exit 1
        fi
    fi
}

compare_build_versions() {
    first_build="$1"
    second_build="$2"
    
    first_build_darwin=${first_build:0:2}
    second_build_darwin=${second_build:0:2}
    first_build_letter=${first_build:2:1}
    second_build_letter=${second_build:2:1}
    first_build_minor=${first_build:3}
    second_build_minor=${second_build:3}
    first_build_minor_no=${first_build_minor//[!0-9]/}
    second_build_minor_no=${second_build_minor//[!0-9]/}
    first_build_minor_beta=${first_build_minor//[0-9]/}
    second_build_minor_beta=${second_build_minor//[0-9]/}

    builds_match="no"
    versions_match="no"
    os_matches="no"

    echo "   [compare_build_versions] Comparing (1) $first_build with (2) $second_build"
    if [[ "$first_build" == "$second_build" ]]; then
        echo "   [compare_build_versions] $first_build = $second_build"
        builds_match="yes"
        versions_match="yes"
        os_matches="yes"
        return
    elif [[ $first_build_darwin -gt $second_build_darwin ]]; then
        echo "   [compare_build_versions] $first_build > $second_build"
        first_build_newer="yes"
        first_build_major_newer="yes"
        return
    elif [[ $first_build_letter > $second_build_letter && $first_build_darwin -eq $second_build_darwin ]]; then
        echo "   [compare_build_versions] $first_build > $second_build"
        first_build_newer="yes"
        first_build_minor_newer="yes"
        os_matches="yes"
        return
    elif [[ ! $first_build_minor_beta && $second_build_minor_beta && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
        echo "   [compare_build_versions] $first_build > $second_build (production > beta)"
        first_build_newer="yes"
        first_build_patch_newer="yes"
        versions_match="yes"
        os_matches="yes"
        return
    elif [[ ! $first_build_minor_beta && ! $second_build_minor_beta && $first_build_minor_no -lt 1000 && $second_build_minor_no -lt 1000 && $first_build_minor_no -gt $second_build_minor_no && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
        echo "   [compare_build_versions] $first_build > $second_build"
        first_build_newer="yes"
        first_build_patch_newer="yes"
        versions_match="yes"
        os_matches="yes"
        return
    elif [[ ! $first_build_minor_beta && ! $second_build_minor_beta && $first_build_minor_no -ge 1000 && $second_build_minor_no -ge 1000 && $first_build_minor_no -gt $second_build_minor_no && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
        echo "   [compare_build_versions] $first_build > $second_build (both betas)"
        first_build_newer="yes"
        first_build_patch_newer="yes"
        versions_match="yes"
        os_matches="yes"
        return
    elif [[ $first_build_minor_beta && $second_build_minor_beta && $first_build_minor_no -ge 1000 && $second_build_minor_no -ge 1000 && $first_build_minor_no -gt $second_build_minor_no && $first_build_letter == "$second_build_letter" && $first_build_darwin -eq $second_build_darwin ]]; then
        echo "   [compare_build_versions] $first_build > $second_build (both betas)"
        first_build_patch_newer="yes"
        first_build_newer="yes"
        versions_match="yes"
        os_matches="yes"
        return
    fi

}

confirm() {
    if [[ $use_depnotify == "yes" ]]; then
        # DEPNotify dialog option
        echo "   [$script_name] Opening DEPNotify confirmation message (language=$user_language)"
        if [[ $fs == "yes" && ! $rebootdelay -gt 10 ]]; then 
            window_type="fs"
        else
            window_type="utility"
        fi
        if [[ $erase == "yes" ]]; then
            dn_title="${!dialog_erase_title}"
            dn_desc="${!dialog_erase_confirmation_desc}"
        else
            dn_title="${!dialog_reinstall_title}"
            dn_desc="${!dialog_reinstall_confirmation_desc}"
        fi
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
        if [[ -f "$depnotify_confirmation_file" ]]; then
            confirmation=2
        else
            confirmation=0
        fi
        # now clear the button, quit key and dialog
        dep_notify_quit
    elif [[ -f "$jamfHelper" ]]; then
        # jamfHelper dialog option
        echo "   [$script_name] Opening jamfHelper confirmation message (language=$user_language)"
        if [[ $erase == "yes" ]]; then
            jh_title="${!dialog_erase_title}"
            jh_desc="${!dialog_erase_confirmation_desc}"
        else
            jh_title="${!dialog_reinstall_title}"
            jh_desc="${!dialog_reinstall_confirmation_desc}"
        fi
        "$jamfHelper" -windowType utility -title "$jh_title" -alignHeading center -alignDescription natural -description "$jh_desc" -lockHUD -icon "$dialog_confirmation_icon" -button1 "${!dialog_cancel_button}" -button2 "${!dialog_confirmation_button}" -defaultButton 1 -cancelButton 1 2> /dev/null
        confirmation=$?
    else
        # osascript dialog option
        echo "   [$script_name] Opening osascript dialog for confirmation (language=$user_language)"
        if [[ $erase == "yes" ]]; then
            osa_desc="${!dialog_erase_confirmation_desc}"
        else
            osa_desc="${!dialog_reinstall_confirmation_desc}"
        fi
        answer=$(
            /bin/launchctl asuser "$current_uid" /usr/bin/osascript <<-END
                set nameentry to button returned of (display dialog "$osa_desc" buttons {"${!dialog_confirmation_button}", "${!dialog_cancel_button}"} default button "${!dialog_cancel_button}" with icon 2)
END
)
        if [[ "$answer" == "${!dialog_confirmation_button}" ]]; then
            confirmation=2
        else
            confirmation=0
        fi
    fi
    if [[ "$confirmation" == "0"* ]]; then
        echo "   [$script_name] User DECLINED erase-install or reinstall"
        exit 0
    elif [[ "$confirmation" == "2"* ]]; then
        echo "   [$script_name] User CONFIRMED erase-install or reinstall"
    else
        echo "   [$script_name] User FAILED to confirm erase-install or reinstall"
        exit 1
    fi
}

create_launchdaemon_to_remove_workdir () {
    # Name of LaunchDaemon
    plist_label="com.github.grahampugh.erase-install.remove"
    launch_daemon="/Library/LaunchDaemons/$plist_label.plist"
    # Create the plist
    /usr/bin/defaults write "$launch_daemon" Label -string "$plist_label"
    /usr/bin/defaults write "$launch_daemon" ProgramArguments -array \
        -string /bin/rm \
        -string -Rf \
        -string "$workdir" \
        -string "$launch_daemon"
    /usr/bin/defaults write "$launch_daemon" RunAtLoad -boolean yes
    /usr/bin/defaults write "$launch_daemon" LaunchOnlyOnce -boolean yes

    /usr/sbin/chown root:wheel "$launch_daemon"
    /bin/chmod 644 "$launch_daemon"
}

dep_notify() {
    # configuration taken from https://github.com/jamf/DEPNotify-Starter
    DEP_NOTIFY_CONFIG_PLIST="/Users/$current_user/Library/Preferences/menu.nomad.DEPNotify.plist"
    # /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" pathToPlistFile "$DEP_NOTIFY_USER_INPUT_PLIST"
    STATUS_TEXT_ALIGN="center"
    /usr/bin/defaults write "$DEP_NOTIFY_CONFIG_PLIST" statusTextAlignment "$STATUS_TEXT_ALIGN"
    chown "$current_user":staff "$DEP_NOTIFY_CONFIG_PLIST"

    # Configure the window's look
    {
        echo "Command: Image: $dn_icon"
        echo "Command: MainTitle: $dn_title"
        echo "Command: MainText: $dn_desc"
    } >> "$depnotify_log"

    if [[ "$dn_button" ]]; then
        echo "Adding DEPNotify button $dn_button" ## TEMP
        echo "Command: ContinueButton: $dn_button" >> "$depnotify_log"
    fi

    if ! pgrep DEPNotify ; then
        # Opening the app after initial configuration
        if [[ "$window_type" == "fs" && ! "$rebootdelay" -gt 10 ]]; then
            sudo -u "$current_user" open -a "$depnotify_app" --args -path "$depnotify_log" -fullScreen
        else
            sudo -u "$current_user" open -a "$depnotify_app" --args -path "$depnotify_log"
        fi
    fi

    # set message below progress bar
    echo "Status: $dn_status" >> "$depnotify_log"

    # set alternaitve quit key (default is X)
    if [[ $dn_quit_key ]]; then
        echo "Command: QuitKey: $dn_quit_key" >> "$depnotify_log"
    fi

}

dep_notify_progress() {
    # function for DEPNotify to show progress while the installer is being downloaded or prepared
    last_progress_value=0
    current_progress_value=0

    if [[ "$1" == "startosinstall" ]]; then
        # Wait for the preparing process to start and set the progress bar to 100 steps
        until grep -q "Preparing: \d" "$LOG_FILE" ; do
            sleep 2
        done
        echo "Status: $dn_status - 0%" >> $depnotify_log
        echo "Command: DeterminateManual: 100" >> $depnotify_log

        # Until at least 100% is reached, calculate the preparing progress and move the bar accordingly
        until [[ $current_progress_value -ge 100 ]]; do
            until [[ $current_progress_value -gt $last_progress_value ]]; do
                current_progress_value=$(tail -1 "$LOG_FILE" | awk 'END{print substr($NF, 1, length($NF)-3)}')
                sleep 2
            done
            echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $depnotify_log
            echo "Status: $dn_status - $current_progress_value%" >> $depnotify_log
            last_progress_value=$current_progress_value
        done

    elif [[ "$1" == "installinstallmacos" ]]; then
        # Wait for the download to start and set the progress bar to 100 steps
        until grep -q "Total" "$LOG_FILE" ; do
            sleep 2
        done
        echo "Status: $dn_status - 0%" >> $depnotify_log
        echo "Command: DeterminateManual: 100" >> $depnotify_log
        sleep 2
        until [[ $current_progress_value -gt 0 && $current_progress_value -lt 100 ]]; do
                current_progress_value=$(tail -1 "$LOG_FILE" | awk '{print substr($(NF-9), 1, length($NF))}')
                sleep 2
        done

        # Until at least 100% is reached, calculate the downloading progress and move the bar accordingly
        until [[ $current_progress_value -ge 100 ]]; do
            until [[ $current_progress_value -gt $last_progress_value ]]; do
                current_progress_value=$(tail -1 "$LOG_FILE" | awk '{print substr($(NF-9), 1, length($NF))}')
                sleep 2
            done
            echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $depnotify_log
            echo "Status: $dn_status - $current_progress_value%" >> $depnotify_log
            last_progress_value=$current_progress_value
        done

    elif [[ "$1" == "fetch-full-installer" ]]; then
        # Wait for the download to start and set the progress bar to 100 steps
        until grep -q "Installing:" "$LOG_FILE" ; do
            sleep 2
        done
        echo "Status: $dn_status - 0%" >> $depnotify_log
        echo "Command: DeterminateManual: 100" >> $depnotify_log

        # Until at least 100% is reached, calculate the downloading progress and move the bar accordingly
        until [[ "$current_progress_value" -ge 100 ]]; do
            until [ "$current_progress_value" -gt "$last_progress_value" ]; do
                current_progress_value=$(tail -1 "$LOG_FILE" | awk 'END{print substr($NF, 1, length($NF)-3)}')
                sleep 2
            done
            echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $depnotify_log
            echo "Status: $dn_status - $current_progress_value%" >> $depnotify_log
            last_progress_value=$current_progress_value
        done

    elif [[ "$1" == "reboot-delay" ]]; then
        # Countdown seconds to reboot (a bit shorter than rebootdelay)
        countdown=$((rebootdelay-5))
        echo "Status: $dn_status - ${countdown}s" >> $depnotify_log
        echo "Command: DeterminateManual: $rebootdelay" >> $depnotify_log
        until [ "$countdown" -eq 0 ]; do
            sleep 1
            countdown=$((countdown-1))
            current_progress_value=$countdown
            echo "Command: DeterminateManualStep: $((current_progress_value-last_progress_value))" >> $depnotify_log
            echo "Status: $dn_status - ${countdown}s" >> $depnotify_log
            last_progress_value=$current_progress_value
        done

    fi
}

dep_notify_quit() {
    # quit DEP Notify
    echo "Command: Quit" >> "$depnotify_log"
    # reset all the settings that might be used again
    /bin/rm "$depnotify_log" "$depnotify_confirmation_file" 2>/dev/null
    dn_button=""
    dn_quit_key=""
    dn_cancel=""
    # kill dep_notify_progress background job if it's already running
    if [ -f "/tmp/depnotify_progress_pid" ]; then
        while read -r i; do
            kill -9 "${i}"
        done < /tmp/depnotify_progress_pid
        /bin/rm /tmp/depnotify_progress_pid
    fi
}

find_existing_installer() {
    # Search for an existing download
    # First let's see if this script has been run before and left an installer
    existing_macos_dmg=$( find $workdir/*.dmg -maxdepth 1 -type f -print -quit 2>/dev/null )
    existing_sparseimage=$( find "$workdir/"*.sparseimage -maxdepth 1 -type f -print -quit 2>/dev/null )
    existing_installer_app=$( find "$installer_directory/Install macOS"*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
    existing_installer_pkg=$( find "$workdir/InstallAssistant"*.pkg -maxdepth 1 -type f -print -quit 2>/dev/null )

    if [[ -f "$existing_macos_dmg" ]]; then
        echo "   [find_existing_installer] Installer image found at $existing_macos_dmg."
        hdiutil attach "$existing_macos_dmg"
        existing_installer_app=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        check_installer_is_valid
    elif [[ -f "$existing_sparseimage" ]]; then
        echo "   [find_existing_installer] Installer sparse image found at $existing_sparseimage."
        hdiutil attach "$existing_sparseimage"
        existing_installer_app=$( find '/Volumes/'*macOS*/Applications/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        check_installer_is_valid
    elif [[ -d "$existing_installer_app" ]]; then
        echo "   [find_existing_installer] Installer found at $existing_installer_app."
        app_is_in_applications_folder="yes"
        check_installer_is_valid
    elif [[ -f "$existing_installer_pkg" ]]; then
        echo "   [find_existing_installer] InstallAssistant package found at $existing_installer_pkg."
        check_installer_pkg_is_valid
    else
        echo "   [find_existing_installer] No valid installer found."
        if [[ $clear_cache == "yes" ]]; then
            exit
        fi
    fi
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

get_darwin_from_os_version() {
    # convert a macOS major version to a darwin version
    os_version="$1"
    if [[ "${os_version:0:2}" == "10" ]]; then
        darwin_version=${os_version:3:2}
        darwin_version=$((darwin_version+4))
    else
        darwin_version=${os_version:0:2}
        darwin_version=$((darwin_version+9))
    fi
    echo "$darwin_version"
}

get_depnotify() {
    # grab installinstallmacos.py if not already there
    # note this does a SHA256 checksum check and will delete the file and exit if this fails
    if [[ -d "$depnotify_app" ]]; then
        echo "   [get_depnotify] DEPNotify is installed ($depnotify_app)"
    else
        if [[ ! $no_curl ]]; then
            echo "   [get_depnotify] Downloading DEPNotify.app..."
            if /usr/bin/curl -L "$depnotify_download_url" -o "$workdir/DEPNotify.pkg" ; then
                if ! installer -pkg "$workdir/DEPNotify.pkg" -target / ; then
                    echo "   [get_depnotify] DEPNotify installation failed"
                fi
            else
                echo "   [get_depnotify] DEPNotify download failed"
            fi
        fi
        # check it did actually get downloaded
        if [[ -d "$depnotify_app" ]]; then
            echo "   [get_depnotify] DEPNotify is installed"
            use_depnotify="yes"
            dep_notify_quit
        else
            echo "   [get_depnotify] Could not download DEPNotify.app."
        fi
    fi
}

get_installinstallmacos() {
    # grab installinstallmacos.py if not already there
    # note this does a SHA256 checksum check and will delete the file and exit if this fails
    if [[ ! -f "$workdir/installinstallmacos.py" || $force_installinstallmacos == "yes" ]]; then
        if [[ ! $no_curl ]]; then
            echo "   [get_installinstallmacos] Downloading installinstallmacos.py..."
            # delete existing version so curl can create new file 
            if [[ -f "$workdir/installinstallmacos.py" ]]; then
                /bin/rm "$workdir/installinstallmacos.py"
            fi
            # use curl -o instead of > redirect, which causes permission error when run with sudo
            /usr/bin/curl -H 'Cache-Control: no-cache' -s "$installinstallmacos_url" -o "$workdir/installinstallmacos.py"
            if echo "$installinstallmacos_checksum  $workdir/installinstallmacos.py" | shasum -c; then
                echo "   [get_installinstallmacos] downloaded new installinstallmacos.py successfully."
            else    
                echo "   [get_installinstallmacos] ERROR: downloaded installinstallmacos.py does not match checksum. Possible corrupted file. Deleting file."
                /bin/rm "$workdir/installinstallmacos.py"
            fi
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

: <<-LICENSE_BLOCK
ljt.min - Little JSON Tool (https://github.com/brunerd/ljt) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#v1.0.3 - use the minified function below to embed ljt into your shell script
ljt() ( 
	[ -n "${-//[^x]/}" ] && set +x; read -r -d '' JSCode <<-'EOT'
	try {var query=decodeURIComponent(escape(arguments[0]));var file=decodeURIComponent(escape(arguments[1]));if (query[0]==='/'){ query = query.split('/').slice(1).map(function (f){return "["+JSON.stringify(f)+"]"}).join('')}if(/[^A-Za-z_$\d\.\[\]'"]/.test(query.split('').reverse().join('').replace(/(["'])(.*?)\1(?!\\)/g, ""))){throw new Error("Invalid path: "+ query)};if(query[0]==="$"){query=query.slice(1,query.length)};var data=JSON.parse(readFile(file));var result=eval("(data)"+query)}catch(e){printErr(e);quit()};if(result !==undefined){result!==null&&result.constructor===String?print(result): print(JSON.stringify(result,null,2))}else{printErr("Node not found.")}
	EOT
	queryArg="${1}"; fileArg="${2}";jsc=$(find "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/" -name 'jsc');[ -z "${jsc}" ] && jsc=$(which jsc);[ -f "${queryArg}" -a -z "${fileArg}" ] && fileArg="${queryArg}" && unset queryArg;if [ -f "${fileArg:=/dev/stdin}" ]; then { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "${fileArg}"; } 1>&3 ; } 2>&1); } 3>&1;else { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "/dev/stdin" <<< "$(cat)"; } 1>&3 ; } 2>&1); } 3>&1; fi;if [ -n "${errOut}" ]; then /bin/echo "$errOut" >&2; return 1; fi
)

get_relocatable_python() {
    # grab macadmins python and install it if not already there - used when running this script as a standalone
    if [[ -L "$relocatable_python_path" && -e "$relocatable_python_path" ]]; then
        echo "   [get_relocatable_python] Relocatable Python is installed in $workdir"
        python_path="$relocatable_python_path"
    elif [[ -L "$macadmins_python_path" && -e "$macadmins_python_path" ]]; then
        echo "   [get_relocatable_python] MacAdmins Python is installed"
        python_path="$macadmins_python_path"
    else
        if [[ ! $no_curl ]]; then
            echo "   [get_relocatable_python] Downloading MacAdmins Python package..."
            macadmins_python_json=$( /usr/bin/curl -sl -H "Accept: application/vnd.github.v3+json" "$macadmins_python_url" )
            macadmins_python_pkg=$( ljt /assets/1/browser_download_url <<< "$macadmins_python_json" )
            /usr/bin/curl -L "$macadmins_python_pkg" -o "$workdir/macadmins_python-$macadmins_python_version.pkg"
            installer -pkg "$workdir/macadmins_python-$macadmins_python_version.pkg" -target /
        fi
        # check it did actually get downloaded
        if [[ -L "$macadmins_python_path" && -e "$macadmins_python_path" ]]; then
            echo "   [get_relocatable_python] MacAdmins Python is installed"
            python_path="$macadmins_python_path"
        else
            echo "   [get_relocatable_python] Could not download MacAdmins Python."
            # fall back to python2
            python_path=$(which python)
        fi
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
            echo "   [get_user_details] User cancelled."
            exit 1
        fi
    fi

    # check that this user exists
    if ! /usr/sbin/dseditgroup -o checkmember -m "$account_shortname" everyone ; then
        echo "   [get_user_details] $account_shortname account cannot be found!"
        user_invalid
        exit 1
    fi

    # check that the user is a Volume Owner
    user_is_volume_owner=0
    users=$(/usr/sbin/diskutil apfs listUsers /)
    enabled_users=""
    while read -r line ; do
        user=$(/usr/bin/cut -d, -f1 <<< "$line")
        guid=$(/usr/bin/cut -d, -f2 <<< "$line")
		# passwords are case sensitive, account names are not
		shopt -s nocasematch
        if [[ $(/usr/bin/grep -A2 "$guid" <<< "$users" | /usr/bin/tail -n1 | /usr/bin/awk '{print $NF}') == "Yes" ]]; then
            enabled_users+="$user "
			# The entered username might not match the output of fdesetup, so we compare
			# all RecordNames for the canonical name given by fdesetup against the entered
			# username, and then use the canonical version. The entered username might
			# even be the RealName, and we still would end up here.
			# Example:
			# RecordNames for user are "John.Doe@pretendco.com" and "John.Doe", fdesetup
			# says "John.Doe@pretendco.com", and account_shortname is "john.doe" or "Doe, John"
			user_record_names_xml=$(/usr/bin/dscl -plist /Search -read "Users/$user" RecordName dsAttrTypeStandard:RecordName)
			# loop through recordName array until error (we do not know the size of the array)
			record_name_index=0
			while true; do
				if ! user_record_name=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RecordName:${record_name_index}" /dev/stdin 2>/dev/null <<< "$user_record_names_xml") ; then
				    break
                fi
				if [[ "$account_shortname" == "$user_record_name" ]]; then
					account_shortname=$user
					echo "   [get_user_details] $account_shortname is a Volume Owner"
					user_is_volume_owner=1
					break
				fi
				record_name_index=$((record_name_index+1))
			done
			# if needed, compare the RealName (which might contain spaces)
			if [[ $user_is_volume_owner = 0 ]]; then
				user_real_name=$(/usr/libexec/PlistBuddy -c "print :dsAttrTypeStandard\:RealName:0" /dev/stdin <<< "$(/usr/bin/dscl -plist /Search -read "Users/$user" RealName)")
				if [[ "$account_shortname" == "$user_real_name" ]]; then
					account_shortname=$user
					echo "   [get_user_details] $account_shortname is a Volume Owner"
					user_is_volume_owner=1
				fi
			fi
        fi
		shopt -u nocasematch
    done <<< "$(/usr/bin/fdesetup list)"
    if [[ $enabled_users != "" && $user_is_volume_owner = 0 ]]; then
        echo "   [get_user_details] $account_shortname is not a Volume Owner"
        user_not_volume_owner
        exit 1
    fi

    # get password and check that the password is correct
    password_attempts=1
    password_check="fail"
    while [[ "$password_check" != "pass" ]] ; do
        echo "   [get_user_details] ask for password (attempt $password_attempts/$max_password_attempts)"
        account_password=$(ask_for_password)
        ask_for_password_rc=$?
        # prevent accidental cancelling by simply pressing return (entering an empty password)
        if [[ "$ask_for_password_rc" -ne 0 ]]; then
            echo "   [get_user_details] User cancelled."
            exit 1
        fi
        check_password "$account_shortname" "$account_password"

        if [[ ( "$password_check" != "pass" ) && ( $max_password_attempts != "infinite" ) && ( $password_attempts -ge $max_password_attempts ) ]]; then
            # open_osascript_dialog syntax: title, message, button1, icon
            open_osascript_dialog "${!dialog_invalid_password}: $user" "" "OK" 2 
            exit 1
        fi
        password_attempts=$((password_attempts+1))
    done

    # if we are performing eraseinstall the user needs to be an admin so let's promote the user
    if [[ $erase == "yes" ]]; then
        if ! /usr/sbin/dseditgroup -o checkmember -m "$account_shortname" admin ; then
            if /usr/sbin/dseditgroup -o edit -a "$account_shortname" admin ; then
                echo "   [get_user_details] $account_shortname account has been promoted to admin so that eraseinstall can proceed"
                promoted_user="$account_shortname"
            else
                echo "   [get_user_details] $account_shortname account could not be promoted to admin so eraseinstall cannot proceed"
                user_invalid
                exit 1
            fi
        fi
    fi
}

kill_process() {
    process="$1"
    echo
    if process_pid=$(/usr/bin/pgrep -a "$process" 2>/dev/null) ; then 
        echo "   [$script_name] attempting to terminate the '$process' process - Termination message indicates success"
        kill "$process_pid" 2> /dev/null
        if /usr/bin/pgrep -a "$process" >/dev/null ; then 
            echo "   [$script_name] ERROR: '$process' could not be killed"
        fi
        echo
    fi
}

move_to_applications_folder() {
    if [[ $app_is_in_applications_folder == "yes" ]]; then
        echo "   [move_to_applications_folder] Valid installer already in $installer_directory folder"
    else
        echo "   [move_to_applications_folder] Moving installer to $installer_directory folder"
        cp -R "$working_macos_app" $installer_directory/
        existing_installer=$( find /Volumes/*macOS* -maxdepth 2 -type d -name "Install*.app" -print -quit 2>/dev/null )
        if [[ -d "$existing_installer" ]]; then
            echo "   [move_to_applications_folder] Mounted installer will be unmounted: $existing_installer"
            existing_installer_mount_point=$(echo "$existing_installer" | cut -d/ -f 1-3)
            diskutil unmount force "$existing_installer_mount_point"
        fi
        rm -f "$existing_macos_dmg" "$existing_sparseimage"
        working_macos_app=$( find "$installer_directory/Install macOS"*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        echo "   [move_to_applications_folder] Installer moved to $installer_directory folder"
    fi
}

open_osascript_dialog() {
    title="$1"
    message="$2"
    button1="$3"
    icon="$4"

    if [[ $message ]]; then
        /bin/launchctl asuser "$current_uid" /usr/bin/osascript <<-END
            display dialog "$message" ¬
            buttons {"$button1"} ¬
            default button 1 ¬
            with title "$title" ¬
            with icon $icon
END
    else
        /bin/launchctl asuser "$current_uid" /usr/bin/osascript <<-END
            display dialog "$title" ¬
            buttons {"$button1"} ¬
            default button 1 ¬
            with icon $icon
END
    fi
}

overwrite_existing_installer() {
    echo "   [overwrite_existing_installer] Overwrite option selected. Deleting existing version."
    existing_installer=$( find /Volumes/*macOS* -maxdepth 2 -type d -name "Install*.app" -print -quit 2>/dev/null )
    if [[ -d "$existing_installer" ]]; then
        echo "   [$script_name] Mounted installer will be unmounted: $existing_installer"
        existing_installer_mount_point=$(echo "$existing_installer" | cut -d/ -f 1-3)
        diskutil unmount force "$existing_installer_mount_point"
    fi
    rm -f "$existing_macos_dmg" "$existing_sparseimage"
    rm -rf "$existing_installer_app"
    app_is_in_applications_folder=""
    if [[ $clear_cache == "yes" ]]; then
        echo "   [overwrite_existing_installer] Cached installers have been removed. Quitting script as --clear-cache-only option was selected"
        exit
    fi
}

run_installinstallmacos() {
    # Download installinstallmacos.py and MacAdmins Python
    get_installinstallmacos
    if [[ ! -f "$python_path" ]]; then
        get_relocatable_python
    fi

    # Use installinstallmacos.py to download the desired version of macOS
    installinstallmacos_args=()
    installinstallmacos_args+=("--workdir")
    installinstallmacos_args+=("$workdir")

    if [[ $list == "yes" ]]; then
        echo "   [run_installinstallmacos] List only mode chosen"
        installinstallmacos_args+=("--list")
        installinstallmacos_args+=("--warnings")
    else
        installinstallmacos_args+=("--ignore-cache")
    fi

    if [[ $pkg_installer ]]; then 
        installinstallmacos_args+=("--pkg")
    else
        installinstallmacos_args+=("--raw")
    fi

    if [[ $catalogurl ]]; then
        echo "   [run_installinstallmacos] Non-standard catalog URL selected"
        installinstallmacos_args+=("--catalogurl")
        installinstallmacos_args+=("$catalogurl")
    elif [[ $seedprogram ]]; then
        echo "   [run_installinstallmacos] Non-standard seedprogram selected"
        installinstallmacos_args+=("--seed")
        installinstallmacos_args+=("$seedprogram")
    elif [[ $catalog ]]; then
        darwin_version=$(get_darwin_from_os_version "$catalog")
        echo "   [run_installinstallmacos] Non-default catalog selected (darwin version $darwin_version)"
        installinstallmacos_args+=("--catalog")
        installinstallmacos_args+=("$darwin_version")
    fi

    if [[ $beta == "yes" ]]; then
        echo "   [run_installinstallmacos] Beta versions included"
        installinstallmacos_args+=("--beta")
    fi

    if [[ $prechosen_os ]]; then
        echo "   [run_installinstallmacos] Checking that selected OS $prechosen_os is available"
        installinstallmacos_args+=("--os")
        installinstallmacos_args+=("$prechosen_os")
        [[ ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]] && installinstallmacos_args+=("--validate")

    elif [[ $prechosen_version ]]; then
        echo "   [run_installinstallmacos] Checking that selected version $prechosen_version is available"
        installinstallmacos_args+=("--version")
        installinstallmacos_args+=("$prechosen_version")
        [[ ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]] && installinstallmacos_args+=("--validate")

    elif [[ $prechosen_build ]]; then
        echo "   [run_installinstallmacos] Checking that selected build $prechosen_build is available"
        installinstallmacos_args+=("--build")
        installinstallmacos_args+=("$prechosen_build")
        [[ ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]] && installinstallmacos_args+=("--validate")
    fi

    if [[ $samebuild == "yes" ]]; then
        echo "   [run_installinstallmacos] Checking that current build $system_build is available"
        installinstallmacos_args+=("--current")

    elif [[ $sameos == "yes" ]]; then
        echo "   [run_installinstallmacos] Checking that current OS $system_os_major.$system_os_version is available"
        if [[ $system_os_major == "10" ]]; then
            installinstallmacos_args+=("--os")
            installinstallmacos_args+=("$system_os_major.$system_os_version")
        else
            installinstallmacos_args+=("--os")
            installinstallmacos_args+=("$system_os_major")
        fi
        if [[ $skip_validation != "yes" ]]; then
            [[ $erase == "yes" || $reinstall == "yes" ]] && installinstallmacos_args+=("--validate")
        fi
    fi

    if [[ $list != "yes" && ! $prechosen_os && ! $prechosen_version && ! $prechosen_build && ! $samebuild ]]; then
        echo "   [run_installinstallmacos] Getting current production version"
        installinstallmacos_args+=("--auto")
    fi

    # TEST 
    echo
    echo "   [run_installinstallmacos] This command is now being run:"
    echo
    echo "   installinstallmacos.py ${installinstallmacos_args[*]}"

    # shellcheck disable=SC2086
    if ! "$python_path" "$workdir/installinstallmacos.py" "${installinstallmacos_args[@]}" ; then
        echo "   [run_installinstallmacos] Error obtaining valid installer. Cannot continue."
        echo
        exit 1
    fi

    if [[ $list == "yes" ]]; then
        exit 0
    fi

    # Identify the installer dmg
    downloaded_macos_dmg=$( find $workdir -maxdepth 1 -name 'Install_macOS*.dmg' -type f -print -quit )
    downloaded_sparseimage=$( find $workdir -maxdepth 1 -name 'Install_macOS*.sparseimage' -type f -print -quit )
    downloaded_installer_pkg=$( find $workdir/InstallAssistant*.pkg -maxdepth 1 -type f -print -quit 2>/dev/null )

    if [[ -f "$downloaded_macos_dmg" ]]; then
        echo "   [run_installinstallmacos] Mounting disk image to identify installer app."
        if hdiutil attach "$downloaded_macos_dmg" ; then
            working_macos_app=$( find '/Volumes/'*macOS*/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        else
            echo "   [run_installinstallmacos] ERROR: could not mount $downloaded_macos_dmg"
            exit 1
        fi
    elif [[ -f "$downloaded_sparseimage" ]]; then
        echo "   [run_installinstallmacos] Mounting sparse disk image to identify installer app."
        if hdiutil attach "$downloaded_sparseimage" ; then
            working_macos_app=$( find '/Volumes/'*macOS*/Applications/*.app -maxdepth 1 -type d -print -quit 2>/dev/null )
        else
            echo "   [run_installinstallmacos] ERROR: could not mount $downloaded_sparseimage"
            exit 1
        fi
    elif [[ -f "$downloaded_installer_pkg" ]]; then
        echo "   [run_installinstallmacos] InstallAssistant package downloaded to $downloaded_installer_pkg."
        working_installer_pkg="$downloaded_installer_pkg"
    else
        echo "   [run_installinstallmacos] No disk image found. I guess nothing got downloaded."
        exit 1
    fi
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

swu_list_full_installers() {
    # for 10.15.7 and above we can use softwareupdate --list-full-installers
    set_seedprogram
    echo
    /usr/sbin/softwareupdate --list-full-installers
}

swu_fetch_full_installer() {
    # for 10.15+ we can use softwareupdate --fetch-full-installer
    set_seedprogram

    softwareupdate_args=''
    if [[ $prechosen_version ]]; then
        echo "   [swu_fetch_full_installer] Trying to download version $prechosen_version"
        softwareupdate_args+=" --full-installer-version $prechosen_version"
    fi
    # now download the installer
    echo "   [swu_fetch_full_installer] Running /usr/sbin/softwareupdate --fetch-full-installer $softwareupdate_args"
    # shellcheck disable=SC2086
    /usr/sbin/softwareupdate --fetch-full-installer $softwareupdate_args

    # shellcheck disable=SC2181
    if [[ $? == 0 ]]; then
        # Identify the installer
        if find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null ; then
            existing_installer_app=$( find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null )
            # if we actually want to use this installer we should check that it's valid
            if [[ $erase == "yes" || $reinstall == "yes" ]]; then 
                check_installer_is_valid
                if [[ $invalid_installer_found == "yes" ]]; then
                    echo "   [swu_fetch_full_installer] The downloaded app is invalid for this computer. Try with --version or without --fetch-full-installer"
                    exit 1
                fi
            fi
        else
            echo "   [swu_fetch_full_installer] No install app found. I guess nothing got downloaded."
            exit 1
        fi
    else
        echo "   [swu_fetch_full_installer] softwareupdate --fetch-full-installer failed. Try without --fetch-full-installer option."
        exit 1
    fi
}

unpack_pkg_to_applications_folder() {
    # if dealing with a package we now have to extract it and check it's valid
    if [[ -f "$working_installer_pkg" ]]; then
        echo "   [unpack_pkg_to_applications_folder] Unpacking $working_installer_pkg into /Applications folder"
        if /usr/sbin/installer -pkg "$working_installer_pkg" -tgt / ; then
            working_macos_app=$( find /Applications -maxdepth 1 -name 'Install macOS*.app' -type d -print -quit 2>/dev/null )
            if [[ -d "$working_macos_app" && "$keep_pkg" != "yes" ]]; then
                echo "   [unpack_pkg_to_applications_folder] Deleting $working_installer_pkg"
                rm -f "$working_installer_pkg"
                working_installer_pkg=""
            fi
        else
            echo "   [unpack_pkg_to_applications_folder] ERROR - $working_installer_pkg could not be unpacked"
            exit 1
        fi
    fi
}

user_invalid() {
    # required for Silicon Macs
    # open_osascript_dialog syntax: title, message, button1, icon
    open_osascript_dialog "$account_shortname: ${!dialog_user_invalid}" "" "OK" 2
}

user_not_volume_owner() {
    # required for Silicon Macs
    # open_osascript_dialog syntax: title, message, button1, icon
    open_osascript_dialog "$account_shortname ${!dialog_not_volume_owner}: ${enabled_users}" "" "OK" 2
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
    if [[ -f "$jamfHelper" ]]; then
        # use jamfHelper if possible
        "$jamfHelper" -windowType "utility" -title "${!dialog_power_title}" -description "${!dialog_nopower_desc} ${power_wait_timer_friendly}" -alignDescription "left" -icon "$dialog_confirmation_icon" -button1 "OK" -defaultButton 1 &
    else
        # open_osascript_dialog syntax: title, message, button1, icon
        open_osascript_dialog "${!dialog_nopower_desc}  ${power_wait_timer_friendly}" "" "OK" stop &
    fi
    echo "   [wait_for_power] ERROR - No AC power detected after waiting for ${power_wait_timer_friendly}, cannot continue."
    exit 1
}

show_help() {
    echo "
    [$script_name] by @GrahamRPugh

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
    --seed ...          Select a non-standard seed program
    --catalog ...       Override the default catalog with one from a different OS (overrides seedprogram)
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
    --clear-cache-only  When used in conjunction with --overwrite, --update or --replace-invalid,
                        the existing installer is removed but not replaced. This is useful
                        for running the script after an upgrade to clear the working files.
    --cleanup-after-use Creates a LaunchDaemon to delete $workdir after use. Mainly useful
                        in conjunction with the --reinstall option.
    --move              Moves the downloaded macOS installer to $installer_directory
    --path /path/to     Overrides the destination of --move to a specified directory
    --erase             After download, erases the current system
                        and reinstalls macOS.
    --confirm           Displays a confirmation dialog prior to erasing the current
                        system and reinstalling macOS. 
    --depnotify         Uses DEPNotify for dialogs instead of jamfHelper, if installed.
                        Only applicable with --reinstall and --erase arguments.
    --fs                Uses full-screen DEPNotify windows for all stages, not just the
                        preparation phase. Only works with DEPNotify, not jamfHelper.
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
    --preinstall-command 'some arbitrary command'
                        Supply a shell command to run immediately prior to startosinstall
                        running. An example might be 'jamf recon -department Spare'.
                        Ensure that the command is in quotes.
    --postinstall-command 'some arbitrary command'
                        Supply a shell command to run immediately after startosinstall
                        completes preparation, but before reboot. 
                        An example might be 'jamf recon -department Spare'.
                        Ensure that the command is in quotes.
                      

    Parameters for use with Apple Silicon Mac:
      Note that startosinstall requires user authentication on AS Mac. The user 
      must have a Secure Token. This script checks for the Secure Token of the 
      supplied user. An osascript dialog is used to supply the password, so
      this script cannot be run at the login window or from remote terminal.
    --current-user      Authenticate startosinstall using the current user
    --user XYZ          Supply a user with which to authenticate startosinstall
    --max-password-attempts NN | infinite
                        Overrides the default of 5 attempts to ask for the user's password. Using
                        'infinite' will disable the Cancel button and asking until the password is
                        successfully verified.

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
    --rebootdelay NN    Delays the reboot after preparation has finished by NN seconds (max 300)

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

finish() {
    local exit_code=$?
    # if we promoted the user then we should demote it again
    if [[ $promoted_user ]]; then
        /usr/sbin/dseditgroup -o edit -d "$promoted_user" admin
        echo "     [$script_name] User $promoted_user was demoted back to standard user"
    fi

    # kill caffeinate
    kill_process "caffeinate"

    # kill any dialogs if startosinstall ends before a reboot
    # kill_process "jamfHelper"
    # dep_notify_quit
    exit $exit_code
}

post_prep_work() {
    # set DEPNotify status for rebootdelay if set
    if [[ "$rebootdelay" -gt 10 ]]; then
        if [[ "$use_depnotify" == "yes" ]]; then
            dep_notify_quit
            echo "   [post_prep_work] Opening DEPNotify full screen message (language=$user_language)"
            dn_title="${!dialog_reinstall_title}"
            dn_desc="${!dialog_rebooting_heading}"
            dn_status="${!dialog_rebooting_status}"
            dn_button=""
            dep_notify
            dep_notify_progress reboot-delay >/dev/null 2>&1 &
            echo $! >> /tmp/depnotify_progress_pid
        elif [[ -f "$jamfHelper" ]]; then
            kill_process "jamfHelper"
            sleep 0.5
            echo "   [post_prep_work] Opening jamfHelper message (language=$user_language)"
            window_type="utility"
            "$jamfHelper" -windowType $window_type -title "${!dialog_reinstall_title}" -heading "${!dialog_rebooting_heading}" -description "${!dialog_rebooting_status} ${rebootdelay}s" -icon "$dialog_reinstall_icon" &
        else
            echo "   [post_prep_work] Opening osascript dialog (language=$user_language)"
            # open_osascript_dialog syntax: title, message, button1, icon
            open_osascript_dialog "${!dialog_rebooting_heading}" "" "OK" stop &
        fi
    fi
    # run the postinstall commands
    for command in "${postinstall_command[@]}"; do
        echo "   [$script_name] Now running arbitrary command: $command"
        /bin/bash -c "$command"
    done

    # finish the delay
    sleep "$rebootdelay"

    # then shut everything down
    kill_process "Self Service"
    finish
    exit
}


###############
## MAIN BODY ##
###############

# ensure the finish function is executed when exit is signaled
trap "finish" EXIT

# ensure some cleanup is done after startosinstall is run (thanks @frogor!)
trap "post_prep_work" SIGUSR1  # 30 is the numerical representation of SIGUSR1 (thanks @n8felton)

# Safety mechanism to prevent unwanted wipe while testing
erase="no"
reinstall="no"

# default minimum drive space in GB
# Note that the amount of space required varies between macOS installer and system versions.
# Override this default value with the --min-drive-space option.
min_drive_space=45

# default max_password_attempts to 5
max_password_attempts=5

while test $# -gt 0 ; do
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
        --fs) fs="yes"
            ;;
        --skip-validation) skip_validation="yes"
            ;;
        --current-user) use_current_user="yes"
            ;;
        --user)
            shift
            account_shortname="$1"
            ;;
        --max-password-attempts)
            shift
            if [[ ( $1 == "infinite" ) || ( $1 -gt 0 ) ]]; then
                max_password_attempts="$1"
            fi
            ;;
        --rebootdelay)
            shift
            rebootdelay="$1"
            if [[ $rebootdelay -gt 300 ]]; then
                rebootdelay=300
            fi
            ;;
        --test-run) test_run="yes"
            ;;
        --clear-cache-only) clear_cache="yes"
            ;;
        --cleanup-after-use) cleanup_after_use="yes"
            ;;
        --depnotify) 
            if [[ -d "$depnotify_app" ]]; then
                use_depnotify="yes"
                dep_notify_quit
            else
                get_depnotify_app="yes"
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
        --seed|--seedprogram)
            shift
            seedprogram="$1"
            ;;
        --catalogurl)
            shift
            catalogurl="$1"
            ;;
        --catalog)
            shift
            catalog="$1"
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
        --preinstall-command)
            shift
            preinstall_command+=("$1")
            ;;
        --postinstall-command)
            shift
            postinstall_command+=("$1")
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
        --catalog*)
            catalog=$(echo "$1" | sed -e 's|^[^=]*=||g')
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
        --user*)
            account_shortname=$(echo "$1" | sed -e 's|^[^=]*=||g')
            ;;
        --max-password-attempts*)
            new_max_password_attempts=$(echo "$1" | sed -e 's|^[^=]*=||g')
            if [[ ( $new_max_password_attempts == "infinite" ) || ( $new_max_password_attempts -gt 0 ) ]]; then
                max_password_attempts="$new_max_password_attempts"
            fi
            ;;
        --rebootdelay*)
            rebootdelay=$(echo "$1" | sed -e 's|^[^=]*=||g')
            if [[ $rebootdelay -gt 300 ]]; then
                rebootdelay=300
            fi
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
        --preinstall-command*)
            command=$(echo "$1" | sed -e 's|^[^=]*=||g')
            preinstall_command+=("$command")
            ;;
        --postinstall-command*)
            command=$(echo "$1" | sed -e 's|^[^=]*=||g')
            postinstall_command+=("$command")
            ;;
        -h|--help) show_help
            ;;
    esac
    shift
done

echo
echo "   [$script_name] v$version script execution started: $(date)"

# not giving an option for fetch-full-installer mode for now... /Applications is the path
if [[ $ffi ]]; then
    installer_directory="/Applications"
fi

# ensure installer_directory (--path) and workdir exists
if [[ ! -d "$installer_directory" ]]; then
    echo "   [$script_name] Making installer directory at $installer_directory"
    /bin/mkdir -p "$installer_directory"
fi
if [[ ! -d "$workdir" ]]; then
    echo "   [$script_name] Making working directory at $workdir"
    /bin/mkdir -p "$workdir"
fi

# all output from now on is written also to a log file
LOG_FILE="$workdir/erase-install.log"
exec > >(tee "${LOG_FILE}") 2>&1

# ensure computer does not go to sleep while running this script
echo "   [$script_name] Caffeinating this script (pid=$$)"
/usr/bin/caffeinate -dimsu -w $$ &

# bundled python directory
relocatable_python_path="$workdir/Python.framework/Versions/Current/bin/python3"

# place any extra packages that should be installed as part of the erase-install into this folder. The script will find them and install.
# https://derflounder.wordpress.com/2017/09/26/using-the-macos-high-sierra-os-installers-startosinstall-tool-to-install-additional-packages-as-post-upgrade-tasks/
extras_directory="$workdir/extras"

# variable to prevent installinstallmacos getting downloaded twice
iim_downloaded=0

# if getting a list from softwareupdate then we don't need to make any OS checks
if [[ $list_installers ]]; then
    swu_list_full_installers
    echo
    exit
fi

# some options vary based on installer versions
system_version=$( /usr/bin/sw_vers -productVersion )
system_os_major=$( echo "$system_version" | cut -d '.' -f 1 )
system_os_version=$( echo "$system_version" | cut -d '.' -f 2 )

# check for power and drive space if invoking erase or reinstall options
if [[ $erase == "yes" || $reinstall == "yes" ]]; then
    # announce that the Test Run mode is implemented
    if [[ $test_run == "yes" ]]; then
        echo
        echo "*** TEST-RUN ONLY! ***"
        echo "* This script will perform all tasks up to the point of erase or reinstall,"
        echo "* but will not actually erase or reinstall."
        echo "* Remove the --test-run argument to perform the erase or reinstall."
        echo "**********************"
        echo
    fi

    # get DEPNotify if specified
    if [[ $get_depnotify_app == "yes" ]]; then
        get_depnotify
    fi

    # check there is enough space
    check_free_space

    # check for power
    [[ "$check_power" == "yes" ]] && check_power_status
fi

# Look for the installer, download it if it is not present
echo "   [$script_name] Looking for existing installer app or pkg"
find_existing_installer

if [[ $invalid_installer_found == "yes" && -d "$working_macos_app" && $replace_invalid_installer == "yes" ]]; then
    overwrite_existing_installer
elif [[ $invalid_installer_found == "yes" && ($pkg_installer && ! -f "$working_installer_pkg") && $replace_invalid_installer == "yes" ]]; then
    echo "   [$script_name] Deleting invalid installer package"
    rm -f "$working_macos_app"
    if [[ $clear_cache == "yes" ]]; then
        echo "   [$script_name] Quitting script as --clear-cache-only option was selected."
        # kill caffeinate
        kill_process "caffeinate"
        exit
    fi
elif [[ "$prechosen_build" != "" && "$builds_match" != "yes" ]]; then
    echo "   [$script_name] Existing installer does not match requested build, so replacing..."
    overwrite_existing_installer
elif [[ "$prechosen_version" != "" && "$versions_match" != "yes" ]]; then
    echo "   [$script_name] Existing installer does not match requested version, so replacing..."
    overwrite_existing_installer
elif [[ "$prechosen_os" != "" && "$os_matches" != "yes" ]]; then
    echo "   [$script_name] Existing installer does not match requested version, so replacing..."
    overwrite_existing_installer
elif [[ $update_installer == "yes" && -d "$working_macos_app" && $overwrite != "yes" ]]; then
    echo "   [$script_name] Checking for newer installer"
    check_newer_available
    if [[ $newer_build_found == "yes" ]]; then 
        echo "   [$script_name] Newer installer found so overwriting existing installer"
        overwrite_existing_installer
    elif [[ $clear_cache == "yes" ]]; then
        echo "   [$script_name] Quitting script as --clear-cache-only option was selected."
        # kill caffeinate
        kill_process "caffeinate"
        exit
    fi
elif [[ $update_installer == "yes" && ($pkg_installer && -f "$working_installer_pkg") && $overwrite != "yes" ]]; then
    echo "   [$script_name] Checking for newer installer package"
    check_newer_available
    if [[ $newer_build_found == "yes" ]]; then 
        echo "   [$script_name] Newer installer found so deleting existing installer package"
        rm -f "$working_macos_app"
    fi
    if [[ $clear_cache == "yes" ]]; then
        echo "   [$script_name] Quitting script as --clear-cache-only option was selected."
        # kill caffeinate
        kill_process "caffeinate"
        exit
    fi
elif [[ $overwrite == "yes" && -d "$working_macos_app" && ! $list ]]; then
    overwrite_existing_installer
elif [[ $overwrite == "yes" && ($pkg_installer && -f "$working_installer_pkg") && ! $list ]]; then
    echo "   [$script_name] Deleting invalid installer package"
    rm -f "$working_installer_pkg"
    if [[ $clear_cache == "yes" ]]; then
        echo "   [$script_name] Quitting script as --clear-cache-only option was selected."
        # kill caffeinate
        kill_process "caffeinate"
        exit
    fi
elif [[ $invalid_installer_found == "yes" && ($erase == "yes" || $reinstall == "yes") && $skip_validation != "yes" ]]; then
    echo "   [$script_name] ERROR: Invalid installer is present. Run with --overwrite option to ensure that a valid installer is obtained."
    # kill caffeinate
    kill_process "caffeinate"
    exit 1
fi

# Silicon Macs require a username and password to run startosinstall
# We therefore need to be logged in to proceed, if we are going to erase or reinstall
# This goes before the download so users aren't waiting for the prompt for username
arch=$(/usr/bin/arch)
if [[ "$arch" == "arm64" && ($erase == "yes" || $reinstall == "yes") ]]; then
    if ! pgrep -q Finder ; then
        echo "    [$script_name] ERROR! The startosinstall binary requires a user to be logged in."
        echo
        # kill caffeinate
        kill_process "caffeinate"
        exit 1
    fi
    get_user_details
fi

if [[ (! -d "$working_macos_app" && ! -f "$working_installer_pkg") || $list ]]; then
    # if erasing or reinstalling, open a dialog to state that the download is taking place.
    if [[ $erase == "yes" || $reinstall == "yes" ]]; then
        if [[ $use_depnotify == "yes" ]]; then
            echo "   [$script_name] Opening DEPNotify download message (language=$user_language)"
            # if fs is set, show a full screen display instead of the utility window
            if [[ $fs == "yes" && ! $rebootdelay -gt 10 ]]; then 
                window_type="fs"
            else
                window_type="utility"
            fi
            dn_title="${!dialog_dl_title}"
            dn_desc="${!dialog_dl_desc}"
            dn_status="${!dialog_dl_title}"
            if [[ $reinstall == "yes" && "$rebootdelay" -gt 10 ]]; then
                dn_button="OK"
            else
                dn_button=""
            fi
            dn_icon="$dialog_dl_icon"
            dep_notify
            if [[ -f "$depnotify_confirmation_file" ]]; then
                dep_notify_quit
            fi
        elif [[ -f "$jamfHelper" ]]; then
            echo "   [$script_name] Opening jamfHelper download message (language=$user_language)"
            "$jamfHelper" -windowType hud -windowPosition ul -title "${!dialog_dl_title}" -alignHeading center -alignDescription left -description "${!dialog_dl_desc}" -lockHUD -icon  "$dialog_dl_icon" -iconSize 100 &
        else
            echo "   [$script_name] Opening osascript dialog (language=$user_language)"
            # open_osascript_dialog syntax: title, message, button1, icon
            open_osascript_dialog "${!dialog_dl_title}" "${!dialog_dl_desc}" "OK" 2 &
        fi
    fi

    # now run installinstallmacos or softwareupdate
    if [[ $ffi ]]; then
        if [[ ($system_os_major -eq 10 && $system_os_version -ge 15) || $system_os_major -ge 11 ]]; then
            echo "   [$script_name] OS version is $system_os_major.$system_os_version so can run with --fetch-full-installer option"
            if [[ $use_depnotify == "yes" ]]; then
                # display progress if DEPNotify used
                dep_notify_progress fetch-full-installer >/dev/null 2>&1 &
                echo $! >> /tmp/depnotify_progress_pid
            fi
            swu_fetch_full_installer
        else
            echo "   [$script_name] OS version is $system_os_major.$system_os_version so cannot run with --fetch-full-installer option. Falling back to installinstallmacos.py"
            if [[ $use_depnotify == "yes" ]]; then
                # display progress if DEPNotify used
                dep_notify_progress installinstallmacos >/dev/null 2>&1 &
                echo $! >> /tmp/depnotify_progress_pid
            fi
            run_installinstallmacos
        fi
    else
        if [[ $use_depnotify == "yes" ]]; then
            # display progress if DEPNotify used
            dep_notify_progress installinstallmacos >/dev/null 2>&1 &
            echo $! >> /tmp/depnotify_progress_pid
        fi
        run_installinstallmacos
    fi
fi

if [[ -d "$working_macos_app" ]]; then
    echo "   [$script_name] Installer is at: $working_macos_app"
fi

# Move to $installer_directory if move_to_applications_folder flag is included
# Not allowed for fetch_full_installer option
if [[ $move == "yes" && ! $ffi ]]; then
    echo "   [$script_name] Invoking --move option"
    if [[ $use_depnotify == "yes" ]]; then
        echo "Status: Moving installer to Applications folder" >> $depnotify_log
    fi
    if [[ -f "$working_installer_pkg" ]]; then
        unpack_pkg_to_applications_folder
    else
        move_to_applications_folder
    fi
fi

# Once finished downloading (and optionally moving), kill the jamfHelper or DEPNotify
if [[ $use_depnotify == "yes" ]]; then
    echo "   [$script_name] Closing DEPNotify download message (language=$user_language)"
    dep_notify_quit
elif [[ -f "$jamfHelper" ]]; then
    echo "   [$script_name] Closing jamfHelper download message (language=$user_language)"
    kill_process "jamfHelper"
fi


if [[ $erase != "yes" && $reinstall != "yes" ]]; then
    # Unmount the dmg
    if [[ ! $ffi ]]; then
        existing_installer=$(find /Volumes/*macOS* -maxdepth 2 -type d -name "Install*.app" -print -quit 2>/dev/null )
        if [[ -d "$existing_installer" ]]; then
            echo "   [$script_name] Mounted installer will be unmounted: $existing_installer"
            existing_installer_mount_point=$(echo "$existing_installer" | cut -d/ -f 1-3)
            diskutil unmount force "$existing_installer_mount_point"
        fi
    fi
    # Clear the working directory
    echo "   [$script_name] Cleaning working directory '$workdir/content'"
    rm -rf "$workdir/content"

    # kill caffeinate
    kill_process "caffeinate"
    echo
    exit
fi

## Steps beyond here are to run startosinstall

echo
if [[ -f "$working_installer_pkg" ]]; then
    # if we still have a packege we need to move it before we can install it
    unpack_pkg_to_applications_folder
fi

if [[ ! -d "$working_macos_app" ]]; then
    echo "   [$script_name] ERROR: Can't find the installer! "
    # kill caffeinate
    kill_process "caffeinate"
    exit 1
fi
[[ $erase == "yes" ]] && echo "   [$script_name] WARNING! Running $working_macos_app with eraseinstall option"
[[ $reinstall == "yes" ]] && echo "   [$script_name] WARNING! Running $working_macos_app with reinstall option"
echo

# If configured to do so, display a confirmation window to the user. Note: default button is cancel
if [[ $confirm == "yes" ]]; then
    confirm
fi

# determine SIP status, as the volume is required if SIP is disabled
/usr/bin/csrutil status | sed -n 1p | grep -q 'disabled' && sip="disabled" || sip="enabled"

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
installer_build=$( /usr/bin/defaults read "$working_macos_app/Contents/Info.plist" DTSDKBuild )
installer_darwin_version=${installer_build:0:2}
# add --preservecontainer to the install arguments if specified (for macOS 10.14 (Darwin 18) and above)
if [[ $installer_darwin_version -ge 18 && $preservecontainer == "yes" ]]; then
    install_args+=("--preservecontainer")
fi

# OS X 10.12 (Darwin 16) requires the --applicationpath option
if [[ $installer_darwin_version -le 16 ]]; then
    install_args+=("--applicationpath")
    install_args+=("$working_macos_app")
fi

# macOS 11 (Darwin 20) and above requires the --allowremoval option
if [[ $installer_darwin_version -ge 20 ]]; then
    install_args+=("--allowremoval")
fi

# macOS 11 (Darwin 20) and above can use the --rebootdelay option
if [[ $installer_darwin_version -ge 20 && "$rebootdelay" -gt 0 ]]; then
    install_args+=("--rebootdelay")
    install_args+=("$rebootdelay")
else
    # cancel rebootdelay for older systems as we don't support it
    rebootdelay=0
fi

# macOS 10.15 (Darwin 19) and above requires the --forcequitapps options
if [[  $installer_darwin_version -ge 19 ]]; then    
    install_args+=("--forcequitapps")
fi

# icons for Jamf Helper erase and re-install windows
dialog_erase_icon="$working_macos_app/Contents/Resources/InstallAssistant.icns"
dialog_reinstall_icon="$working_macos_app/Contents/Resources/InstallAssistant.icns"

# if no_fs is set, show a utility window instead of the full screen display (for test purposes)
if [[ $no_fs == "yes" || $rebootdelay -gt 10 ]]; then 
    window_type="utility"
else
    window_type="fs"
fi

# dialogs for erase
if [[ $erase == "yes" ]]; then
    if [[ $use_depnotify == "yes" ]]; then
        echo "   [$script_name] Opening DEPNotify message (language=$user_language)"
        dn_title="${!dialog_erase_title}"
        dn_desc="${!dialog_erase_desc}"
        dn_status="${!dialog_reinstall_status}"
        dn_icon="$dialog_erase_icon"
        dn_button=""
        dep_notify
        dep_notify_progress startosinstall >/dev/null 2>&1 &
        echo $! >> /tmp/depnotify_progress_pid
        if [[ -f "$depnotify_confirmation_file" ]]; then
            dep_notify_quit
        fi
    elif [[ -f "$jamfHelper" ]]; then
        echo "   [$script_name] Opening jamfHelper message (language=$user_language)"
        "$jamfHelper" -windowType $window_type -title "${!dialog_erase_title}" -heading "${!dialog_erase_title}" -description "${!dialog_erase_desc}" -icon "$dialog_erase_icon" &
    else
        echo "   [$script_name] Opening osascript dialog (language=$user_language)"
        # open_osascript_dialog syntax: title, message, button1, icon
        open_osascript_dialog "${!dialog_erase_desc}" "" "OK" stop &
    fi

# dialogs for reinstallation
elif [[ $reinstall == "yes" ]]; then
    if [[ $use_depnotify == "yes" ]]; then
        echo "   [$script_name] Opening DEPNotify message (language=$user_language)"
        dn_title="${!dialog_reinstall_title}"
        dn_desc="${!dialog_reinstall_desc}"
        dn_status="${!dialog_reinstall_status}"
        dn_icon="$dialog_reinstall_icon"
        if [[ "$rebootdelay" -gt 10 ]]; then
            dn_button="OK"
        else
            dn_button=""
        fi
        dep_notify
        dep_notify_progress startosinstall >/dev/null 2>&1 &
        echo $! >> /tmp/depnotify_progress_pid
        if [[ -f "$depnotify_confirmation_file" ]]; then
            dep_notify_quit
        fi
    elif [[ -f "$jamfHelper" ]]; then
        echo "   [$script_name] Opening jamfHelper message (language=$user_language)"
        "$jamfHelper" -windowType $window_type -title "${!dialog_reinstall_title}" -heading "${!dialog_reinstall_heading}" -description "${!dialog_reinstall_desc}" -icon "$dialog_reinstall_icon" &
    else
        echo "   [$script_name] Opening osascript dialog (language=$user_language)"
        # open_osascript_dialog syntax: title, message, button1, icon
        open_osascript_dialog "${!dialog_reinstall_desc}" "" "OK" stop &
    fi
fi

# set launchdaemon to remove $workdir if $cleanup_after_use is set
if [[ $cleanup_after_use != "" ]]; then
    echo "   [$script_name] Writing LaunchDaemon which will remove $workdir at next boot"
fi

# run preinstall commands
for command in "${preinstall_command[@]}"; do
    echo "   [$script_name] Now running arbitrary command: $command"
    /bin/bash -c "$command"
done

# now actually run startosinstall
if [[ $test_run != "yes" ]]; then
    if [[ $cleanup_after_use != "" ]]; then
        # set launchdaemon to remove $workdir if $cleanup_after_use is set
        create_launchdaemon_to_remove_workdir
    fi
    if [ "$arch" == "arm64" ]; then
        # startosinstall --eraseinstall may fail if a user was converted to admin using the Privileges app
        # this command supposedly fixes this problem (experimental!)
        if [[ "$erase" == "yes" ]]; then
            echo "   [$script_name] updating preboot files (takes a few seconds)..."
            if /usr/sbin/diskutil apfs updatepreboot / > /dev/null; then
                echo "   [$script_name] preboot files updated"
            else
                echo "   [$script_name] WARNING! preboot files could not be updated."
            fi
        fi        
        # shellcheck disable=SC2086
        echo $account_password | "$working_macos_app/Contents/Resources/startosinstall" "${install_args[@]}" --pidtosignal $$ --agreetolicense --nointeraction --stdinpass --user "$account_shortname" "${install_package_list[@]}" & wait $!
    else
        "$working_macos_app/Contents/Resources/startosinstall" "${install_args[@]}" --pidtosignal $$ --agreetolicense --nointeraction "${install_package_list[@]}" & wait $!
    fi

else
    echo "   [$script_name] Run without '--test-run' to run this command:"
    if [ "$arch" == "arm64" ]; then
        echo "echo \"[PASSWORD REDACTED]\" | \"$working_macos_app/Contents/Resources/startosinstall\" \"" "${install_args[@]}" "\" --pidtosignal $$ --agreetolicense --nointeraction --stdinpass --user \"$account_shortname\" \"" "${install_package_list[@]}" "\" & wait $!"
    else
        echo "$working_macos_app/Contents/Resources/startosinstall\" \"" "${install_args[@]}" "\" --pidtosignal $$ --agreetolicense --nointeraction \"" "${install_package_list[@]}" "\" & wait $!"
    fi
    sleep 30
    post_prep_work
fi
