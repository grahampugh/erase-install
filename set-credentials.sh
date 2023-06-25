#!/bin/bash

:<<DOC
Script to create a base-64 encoded string in the form USERNAME:PASSWORD
DOC

echo
echo "Please enter the credentials you wish to encode:"

echo
printf '%s ' 'Enter username : '
read -r -s username
echo
printf '%s ' 'Enter password : '
read -r -s password
echo

b64_credentials=$(printf "%s:%s" "$username" "$password" | iconv -t ISO-8859-1 | base64 -i -)

echo "Your encoded credentials are: $b64_credentials"
echo
