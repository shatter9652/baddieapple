#!/bin/bash
# Written by HarryJarry1
# Thanks to olyb for help with commands.
fail(){
	printf "$1\n"
	printf "error occurred\n"
	exit
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i1)
      image1="$2"
      shift 2
      ;;
    -i2)
      image2="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Example command: sudo ./BadApple2_builder.sh -i1 <image_vulnerable_to_badapple> -i2 <image_on_latest_kernver>"
      shift
      ;;
  esac
done

# check if images were given
if [[ -z "$image1" || -z "$image2" ]]; then
    echo "Error: Both -i1 and -i2 must be specified."
    echo "Example usage: sudo ./BadApple2_builder.sh -i1 <image_vulnerable_to_badapple> -i2 <image_on_latest_kernver>"
    exit 1
fi

# check if running as root

if [[ $EUID -eq 0 ]]; then
       echo ""
     else
       echo "Not running as root, please run with sudo"
       exit
     fi

# commands for editing the images

echo ""
LOOPDEV1=$(losetup -f) || fail "could not find an available loop"
losetup -r -P "$LOOPDEV1" "$image1" || fail "Could not losetup first image, does it exist?"
LOOPDEV2=$(losetup -f) || fail "could not find an available loop"
losetup -P "$LOOPDEV2" "$image2" || fail "Could not losetup second image, does it exist?"
dd if="${LOOPDEV1}p9" of="${LOOPDEV2}p9" bs=4MiB || fail "Failed to swap p9"
dd if="${LOOPDEV1}p10" of="${LOOPDEV2}p10" bs=4MiB || fail "Failed to swap p10"
losetup -d "$LOOPDEV1" || fail "Failed to unmount"
losetup -d "$LOOPDEV2" || fail "Failed to unmount"
echo "Finished, no errors detected"
echo "Modified file saved to $image2, $image1 is unmodified"
