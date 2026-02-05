#!/bin/bash
# Written by HarryTarryJarry
board=$1
recover1=$2
recover2=$3
: "${recover1:=142}"
: "${recover2:=129}"
board=$(echo "$board" | tr '[:upper:]' '[:lower:]') # mw thingy needs lowercase board names
fail(){
	printf "$1\n"
	printf "error occurred\n"
	exit 1
}
if [[ $EUID -ne 0 ]]; then
       fail "Not running as root, please run with sudo"
     fi
if [ -z "$board" ]; then
    echo "Error: please enter a board"
	fail "example command:  sudo ./no_minios_prebuilt.sh <board> <OPTIONAL:version (default is 140 if unset)> <OPTIONAL:version (default is 126 if unset)>"
fi
if [ "$recover1" -gt 142 ]; then
    echo "You are attempting to make a baddieapple image on a unsupport recovery image. Please use a less modern version."
	echo "Current version is $recover1"
	exit 1
fi
if [ "$recover2" -gt 132 ]; then
    echo "You are attempting to make a baddieapple image on a unsupport recovery image. Please use a less modern version."
	echo "Current version is $recover2"
	exit 1
fi

findimage1(){ # Taken from murkmod
    echo "Attempting to find recovery image from https://github.com/MercuryWorkshop/chromeos-releases-data..."
    local mercury_data_url="https://cdn.jsdelivr.net/gh/MercuryWorkshop/chromeos-releases-data/data.json"
    local mercury_url=$(curl -ks "$mercury_data_url" | jq -r --arg board "$board" --arg version "$recover1" '
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
        echo "$mercury_url"
		FINAL_URL_1="$mercury_url"
	else
    	echo "Failed to find the requested recovery image"
		if [ "$recover1" = "142" ]; then
    		recover1="141"
			echo "Trying to find a 141 image, this board doesn't have a 142 image."
			findimage1
		else
			exit 1
		fi
	fi
}
findimage2(){ # Taken from murkmod
    echo "Attempting to find recovery image from https://github.com/MercuryWorkshop/chromeos-releases-data..."
    local mercury_data_url2="https://cdn.jsdelivr.net/gh/MercuryWorkshop/chromeos-releases-data/data.json"
    local mercury_url2=$(curl -ks "$mercury_data_url2" | jq -r --arg board "$board" --arg version "$recover2" '
      .[$board].images
      | map(select(
          .channel == "stable-channel" and
          (.chrome_version | type) == "string" and
          (.chrome_version | startswith($version + "."))
        ))
      | sort_by(.platform_version)
      | .[0].url
    ')

    if [ -n "$mercury_url2" ] && [ "$mercury_url2" != "null" ]; then
        echo "Found a match!"
        echo "$mercury_url2"
		FINAL_URL_2="$mercury_url2"
	else
    	echo "Failed to find the requested recovery image"
    	exit 1
	fi
}
main(){
	echo "Finding new recovery image..."
 	findimage1
  	echo "Finding old recovery image..."
  	findimage2
	download_images
 	flash_to_image
	cleanup
}
download_images(){
	echo "Welcome to the baddieapple builder, that doesn't use prebuilt miniOS images."
	#new image
	echo "Downloading new recovery image"
	curl --progress-bar -k "$FINAL_URL_1" -o recovery.zip || fail "Failed to download recovery image"
	echo "Extracting new recovery image"
	unzip recovery.zip || fail "Failed to unzip recovery image"
	echo "Deleting new recovery image zip (unneeded now)"
	rm recovery.zip || fail "Failed to delete zipped recovery image"
	reco2=$(find . -maxdepth 2 -name "chromeos_*.bin") # 2 incase the zip format changes
	echo "Found new recovery image from archive at $reco2"
 	mv "$reco2" "image2.bin"
  	#old image
	echo "Downloading old recovery image"
	curl --progress-bar -k "$FINAL_URL_2" -o recovery.zip || fail "Failed to download recovery image"
	echo "Extracting old recovery image"
	unzip recovery.zip || fail "Failed to unzip recovery image"
	echo "Deleting old recovery image zip (unneeded now)"
	rm recovery.zip || fail "Failed to delete zipped recovery image"
	reco1=$(find . -maxdepth 2 -name "chromeos_*.bin") # 2 incase the zip format changes
	echo "Found old recovery image from archive at $reco1"
 	mv "$reco1" "image1.bin"
  	image1="image1.bin"
  	image2="image2.bin"
}
# main baddieapple commands from original POC
flash_to_image(){
	echo "Mounting and editing $image2"
	LOOPDEV1=$(losetup -f) || fail "could not find an available loop"
	losetup -r -P "$LOOPDEV1" "$image1" > /dev/null 2>&1 || fail "Could not losetup first image, does it exist?"
	LOOPDEV2=$(losetup -f) || fail "could not find an available loop"
	losetup -P "$LOOPDEV2" "$image2" > /dev/null 2>&1 || fail "Could not losetup second image, does it exist?"
	dd if="${LOOPDEV1}p9" of="${LOOPDEV2}p9" bs=4MiB > /dev/null 2>&1 || fail "Failed to swap p9" #NOTICE:  p9
	dd if="${LOOPDEV1}p10" of="${LOOPDEV2}p10" bs=4MiB > /dev/null 2>&1 || fail "Failed to swap p10" #NOTICE:  p10	
}
cleanup(){
	echo "Cleaning up..."
	losetup -d "$LOOPDEV1" || fail "Failed to unmount dev1"
	losetup -d "$LOOPDEV2" || fail "Failed to unmount dev2"
 	echo "File saved to $image2"
	rm "$image1" > /dev/null 2>&1 || fail "failed to delete miniOS bin"
 }
check_deps() {
	for dep in "$@"; do
		command -v "$dep" &>/dev/null || echo "$dep"
	done
}
trydebianinstall() {
    #shimboot inspired
    if [ -f "/etc/debian_version" ]; then
    echo "attempting to install build deps"
    apt-get install jq wget unzip curl -y
    else
    fail "not debian, install jq, wget, curl, and unzip."
    fi
}
missing_deps=$(check_deps jq wget unzip curl)
[ "$missing_deps" ] && trydebianinstall
main
echo "Success!  No errors detected."
