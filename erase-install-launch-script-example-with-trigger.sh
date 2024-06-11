#!/bin/zsh
# shellcheck shell=bash

: <<DOC 
erase-install run/postinstall script for running a policy trigger to install erase-install and then running erase-install with chosen parameters
by Graham Pugh

Substitute parameters as required for other OSs and workflows.

To see all possible parameters, run erase-install.sh --help
DOC

# call a policy to install erase-install
jamf policy -event install-erase-install

# run erase-install with parameters of your choice
/Library/Management/erase-install/erase-install.sh --os 13 --update --reinstall --cleanup-after-use --check-power

