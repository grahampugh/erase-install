#!/bin/zsh --no-rcs
# shellcheck shell=bash

# -----------------------------------------------------------------------------
# Compare macOS build versions, handling beta builds correctly
# Returns 0 if version1 >= version2, 1 otherwise
# Beta builds (ending with letter) are considered older than release builds
# with the same base version number
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
        # Use string comparison for build numbers (they're designed to sort lexicographically)
        [[ "$base1" > "$base2" || "$base1" == "$base2" ]]
        return $?
    fi
    
    # Base versions are equal, now handle beta logic
    # If both are release builds (no suffix), they're equal
    if [[ -z "$suffix1" && -z "$suffix2" ]]; then
        return 0  # Equal
    fi
    
    # If version1 is release and version2 is beta, version1 is newer
    if [[ -z "$suffix1" && -n "$suffix2" ]]; then
        return 0  # version1 >= version2
    fi
    
    # If version1 is beta and version2 is release, version1 is older
    if [[ -n "$suffix1" && -z "$suffix2" ]]; then
        return 1  # version1 < version2
    fi
    
    # Both are beta builds - earlier letter is newer (a > b > c...)
    [[ "$suffix1" < "$suffix2" || "$suffix1" == "$suffix2" ]]
    return $?
}

is_build_newer_or_equal "$1" "$2"
echo $? "(0 = $1 is newer)" # Return the result of the comparison
