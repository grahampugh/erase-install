#!/bin/zsh
# shellcheck shell=bash

# a script to obtain the URL for a chosen version of InstallAssistant.pkg from Apple's software catalog

catalog_url="https://swscan.apple.com/content/catalogs/others/index-16beta-16-15-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz"
workdir="/Users/Shared/erase-install"
catalog_download_path="$workdir/downloads/$(basename "$catalog_url")"
catalog_plist_path="$workdir/downloads/$(basename "$catalog_url").plist"

# download the catalog if not already present
if [[ ! -d "$workdir/downloads" ]]; then
    mkdir -p "$workdir/downloads"
fi
if [[ ! -f "$catalog_plist_path" ]]; then
    echo "Downloading catalog..."
    curl "$catalog_url" -o "$catalog_download_path"
    if [[ "$catalog_download_path" == *.gz ]]; then
        echo "Unzipping catalog..."
        gunzip -c "$catalog_download_path" > "$catalog_plist_path"
    else
        echo "Catalog already downloaded, ensure the identifier is .plist"
        cp "$catalog_download_path" "$catalog_plist_path"
    fi
fi

# get a list of products from the catalog using plutil
products=$(/usr/libexec/PlistBuddy -c "Print :Products:" "$catalog_plist_path" | sed -n 's/^    \([0-9]\{3\}-[0-9]\{5\}\) = Dict {$/\1/p')

# echo "Available products:"
# print the list of products
# echo "$products"
if [[ -z "$products" ]]; then
    echo "No products found in the catalog."
    exit 1
fi

# create a JSON file to store the product information
json_file="$workdir/downloads/products.json"
if [[ -f "$json_file" ]]; then
    echo "Removing existing JSON file..."
    rm "$json_file"
fi

# for each product, extract the Packages key
echo "Please wait while we process the catalog..."
while read -r product; do
    package_json=$(plutil -extract Products."$product".Packages json -o - "$catalog_plist_path")
    # extract the URL key that ends with InstallAssistant.pkg
    url=$(jq -r 'to_entries | map(select(.value.URL and (.value.URL | endswith("InstallAssistant.pkg")))) | .[0].value.URL // empty' <<< "$package_json")

    if [[ -n "$url" ]]; then
        post_date=$(plutil -extract Products."$product".PostDate raw -o - "$catalog_plist_path" 2>/dev/null)
        pkg_size=$(jq -r 'to_entries | map(select(.value.URL and (.value.URL | endswith("InstallAssistant.pkg")))) | .[0].value.Size // empty' <<< "$package_json")
        # download the associated dist file and extract useful information
        dist_file=$(plutil -extract Products."$product".Distributions.English raw -o - "$catalog_plist_path" 2>/dev/null)
        # echo "File: $dist_file"
        if [[ -z "$dist_file" ]]; then
            echo "No dist file found for product $product."
            continue
        fi
        # download the dist file
        # echo "Downloading dist file for product $product..."
        dist_xml="$workdir/downloads/$(basename "$dist_file").xml"
        if [[ ! -f "$dist_xml" ]]; then
            echo "Downloading dist file..."
            curl -s "$dist_file" -o "$dist_xml"
        fi
        # extract useful information from the dist XML
        title=$(xmllint --xpath 'string(/installer-gui-script/title/text())' "$dist_xml")
        build=$(xmllint --xpath "string(//dict/string[preceding-sibling::key[1]='BUILD']/text())" "$dist_xml")
        version=$(xmllint --xpath "string(//dict/string[preceding-sibling::key[1]='VERSION']/text())" "$dist_xml")
        # extract a list of supported board IDs
        supportedBoardIDs=$(grep "var supportedBoardIDs" "$dist_xml" | sed -E 's/.*\[\s*([^]]+)\].*/\1/' | tr -d "'")

        # extract a list of supported device IDs
        supportedDeviceIDs=$(grep "var supportedDeviceIDs" "$dist_xml" | sed -E 's/.*\[\s*([^]]+)\].*/\1/' | tr -d "'")

        # echo "Product   : $product"
        # echo "Post Date : $post_date"
        # echo "URL       : $url"
        # echo "Title     : $title"
        # echo "Build     : $build"
        # echo "Version   : $version"
        # echo

        # now add the product information to the JSON file
        echo "{" >> "$json_file"
        echo "  \"product\": \"$product\"," >> "$json_file"
        echo "  \"post_date\": \"$post_date\"," >> "$json_file"
        echo "  \"url\": \"$url\"," >> "$json_file"
        echo "  \"title\": \"$title\"," >> "$json_file"
        echo "  \"build\": \"$build\"," >> "$json_file"
        echo "  \"version\": \"$version\"," >> "$json_file"
        echo "  \"pkg_size\": \"$pkg_size\"," >> "$json_file"
        echo "  \"supported_board_ids\": [" >> "$json_file"
        if [[ -n "$supportedBoardIDs" ]]; then
            # convert the comma-separated list to a JSON array, removing any spaces
            supportedBoardIDs=$(echo "$supportedBoardIDs" | tr -d ' ')
            # split the string into an array
            IFS=',' read -rA board_ids_array <<< "$supportedBoardIDs"
            for board_id in "${board_ids_array[@]}"; do
                echo "    \"$board_id\"," >> "$json_file"
            done
            # remove the last comma
            sed -i '' '$ s/,$//' "$json_file"
        fi
        echo "  ]," >> "$json_file"
        echo "  \"supported_device_ids\": [" >> "$json_file"
        if [[ -n "$supportedDeviceIDs" ]]; then
            # convert the comma-separated list to a JSON array, removing any spaces
            supportedDeviceIDs=$(echo "$supportedDeviceIDs" | tr -d ' ')
            # split the string into an array
            IFS=',' read -rA device_ids_array <<< "$supportedDeviceIDs"
            for device_id in "${device_ids_array[@]}"; do
                echo "    \"$device_id\"," >> "$json_file"
            done
            # remove the last comma
            sed -i '' '$ s/,$//' "$json_file"
        fi
        echo "  ]" >> "$json_file"
        echo "}," >> "$json_file"
    fi
done <<< "$products"

# remove the last comma from the JSON file
if [[ -f "$json_file" ]]; then
    sed -i '' '$ s/,$//' "$json_file"
    echo "JSON file created at $json_file"
fi
