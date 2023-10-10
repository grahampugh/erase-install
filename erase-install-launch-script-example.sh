#!/bin/zsh
# shellcheck shell=bash

: <<DOC 
erase-install run/postinstall script for downloading the latest available Install macOS Ventura.app and reinstalling the OS without wiping.
by Graham Pugh

Substitute parameters as required for other OSs and workflows.

To see all possible parameters, run erase-install.sh --help
DOC

/Library/Management/erase-install/erase-install.sh --os 13 --update --reinstall --cleanup-after-use --check-power

