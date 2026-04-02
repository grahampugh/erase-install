#!/bin/zsh --no-rcs
# shellcheck shell=bash

# -----------------------------------------------------------------------------
# Compare macOS build versions, handling beta and forked builds correctly
# Returns 0 if version1 >= version2, 1 otherwise
# -----------------------------------------------------------------------------
is_build_newer_or_equal() {
    local version1="$1" # system
    local version2="$2" # installer
    
    # Extract base version (everything except the last character if it's a lowercase letter)
    local base1 base2 suffix1 suffix2
    
    # Check if version ends with lowercase letter (beta indicator)
    if [[ "$version1" =~ [a-z]$ ]]; then
        base1="${version1%?}"  # Remove last character
        suffix1="${version1: -1}"  # Get last character
    else
        base1="$version1"
        suffix1=""
    fi
    
    if [[ "$version2" =~ [a-z]$ ]]; then
        base2="${version2%?}"
        suffix2="${version2: -1}"
    else
        base2="$version2"
        suffix2=""
    fi
    
    # Compare base versions first
    if [[ "$base1" != "$base2" ]]; then
        # Parse macOS build version components: Darwin version (2 digits) + minor letter + patch number
        # Extract Darwin version (first 2 digits)
        darwin1="${base1:0:2}"
        darwin2="${base2:0:2}"
        
        # Compare Darwin versions numerically
        if [[ "$darwin1" != "$darwin2" ]]; then
            [[ "$darwin1" -ge "$darwin2" ]]
            return $?
        fi
        
        # Darwin versions are equal, compare minor version letter (3rd character)
        minor1="${base1:2:1}"
        minor2="${base2:2:1}"
        
        if [[ "$minor1" != "$minor2" ]]; then
            [[ "$minor1" > "$minor2" ]]
            return $?
        fi
        
        # Darwin and minor versions are equal, compare patch number (remaining digits)
        patch1="${base1:3}"
        patch2="${base2:3}"
        
        # Handle fork builds and beta builds (4-digit patch numbers)
        # For 4-digit numbers, ignore the first digit and use the remaining 3 digits
        # This applies to both fork builds (e.g., 25A8364) and beta builds (e.g., 25A5362a)
        if [[ ${#patch1} -eq 4 ]]; then
            patch1="${patch1:1}"  # Remove first digit for fork builds
        fi
        if [[ ${#patch2} -eq 4 ]]; then
            patch2="${patch2:1}"  # Remove first digit for fork builds
        fi
        
        # Compare patch numbers numerically
        [[ "$patch1" -ge "$patch2" ]]
        return $?
    fi
}

is_build_newer_or_equal "$1" "$2"
if [[ $? -eq 0 ]]; then
    echo "System Build $1 is newer than or equal to Installer Build $2 (return code 0)"
else
    echo "System Build $1 is older than Installer Build $2 (return code 1)"
fi
