#!/bin/bash

# update_platforms.sh - Updates platform JSON configs from Daijishou repository
# Usage: ./update_platforms.sh

# Directory of the script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

API_URL="https://api.github.com/repos/TapiocaFox/Daijishou/contents/platforms"
RAW_BASE_URL="https://raw.githubusercontent.com/TapiocaFox/Daijishou/main/platforms"

echo "Fetching platform list from Daijishou GitHub..."
FILES_JSON=$(curl -s "$API_URL")

# Check if the response is a valid JSON array
if [[ $(echo "$FILES_JSON" | jq -r 'type') != "array" ]]; then
    echo "Error: Could not fetch file list. You might be rate-limited by GitHub API."
    echo "Response: $FILES_JSON"
    exit 1
fi

# Filter for .json files and get their names
JSON_FILES=$(echo "$FILES_JSON" | jq -r '.[] | select(.name | endswith(".json")) | .name')

if [ -z "$JSON_FILES" ]; then
    echo "No .json files found in the remote repository."
    exit 0
fi

TOTAL=$(echo "$JSON_FILES" | wc -l)
echo "Found $TOTAL platform definitions. Checking for differences..."

UPDATED=0
ADDED=0
SKIPPED=0
REMOVED=0

# Keep track of remote filenames for deletion check
declare -A REMOTE_FILES

for FILE in $JSON_FILES; do
    REMOTE_FILES["$FILE"]=1
    RAW_URL="$RAW_BASE_URL/$FILE"
    TEMP_FILE=".temp_$FILE"
    
    # Download the remote file
    curl -s -o "$TEMP_FILE" "$RAW_URL"
    
    if [ ! -f "$FILE" ]; then
        # New file
        mv "$TEMP_FILE" "$FILE"
        echo "[NEW]     $FILE"
        ((ADDED++))
    else
        # Compare with existing file
        if ! cmp -s "$TEMP_FILE" "$FILE"; then
            # File is different, update it
            mv "$TEMP_FILE" "$FILE"
            echo "[UPDATED] $FILE"
            ((UPDATED++))
        else
            # No changes
            rm "$TEMP_FILE"
            ((SKIPPED++))
        fi
    fi
done

# Remove local files that are no longer in the remote repository
echo ""
echo "Checking for obsolete local definitions..."
for LOCAL_FILE in *.json; do
    # Skip if it's not a regular file or if it's already in the remote list
    if [[ -f "$LOCAL_FILE" && -z "${REMOTE_FILES["$LOCAL_FILE"]}" ]]; then
        echo "[REMOVED] $LOCAL_FILE"
        rm "$LOCAL_FILE"
        ((REMOVED++))
    fi
done

echo ""
echo "Update complete!"
echo "Checked: $TOTAL files"
echo "Added:   $ADDED"
echo "Updated: $UPDATED"
echo "Removed: $REMOVED"
echo "Skipped: $SKIPPED"
