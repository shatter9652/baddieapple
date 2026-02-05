#!/bin/bash
board=$1
recover="131"
if [ "$board" = "rex" ]; then
    recover="130"
fi
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
findimage(){ # Taken from murkmod
    echo "Attempting to find recovery image from https://github.com/MercuryWorkshop/chromeos-releases-data..."
    local mercury_data_url="https://raw.githubusercontent.com/MercuryWorkshop/chromeos-releases-data/refs/heads/main/data.json"
    local mercury_url=$(curl -ks "$mercury_data_url" | jq -r --arg board "$board" --arg version "$recover" '
      .[$board].images
      | map(select(
          .channel == "stable-channel" and
          (.chrome_version | type) == "string" and
          (.chrome_version | startswith($version + "."))
        ))
      | sort_by(.platform_version)
      | .[0].url
    ')

    if [ -n "$mercury_url" ] && [ "$mercury_url" != "null" ]; then
        echo "Found a match!"
        MATCH_FOUND=1
        echo "$mercury_url"
        FINAL_URL="$mercury_url"
    else
        echo "Failed to find the requested recovery image"
        exit 1
    fi
}
echo "downloadng $board"
findimage
curl -L $FINAL_URL -o "$board.zip"
unzip "$board.zip"
unzipped=$(find . -maxdepth 2 -name "*"$board"_recovery*")
du "$unzipped"
rm "$board.zip"
echo "download complete!"
echo "extracting minios"
LOOPDEV1=$(losetup -f)
losetup -r -P "$LOOPDEV1" "$unzipped"
echo "loop device ready"
dd if=$LOOPDEV1"p9" of="minios-$board-p9.bin"
dd if=$LOOPDEV1"p10" of="minios-$board-p10.bin"
losetup -d "$LOOPDEV1"
du "minios-$board-p9.bin"
du "minios-$board-p10.bin"
echo "deleting unzipped recovery image"
rm "$unzipped"
zip -j "minios-$board.zip" "minios-$board-p9.bin" "minios-$board-p10.bin"
echo "deleting unzipped minios"
rm "minios-$board-p9.bin"
rm "minios-$board-p10.bin"
echo "$board done!"
