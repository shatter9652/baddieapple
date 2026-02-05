#!/bin/bash
set -e

SCRIPT_VERSION="0.1"
SCRIPT_TYPE="PoC" # can be stable, beta, test, PoC

echo "welcome to the badapple v2 builder."
echo "version v${SCRIPT_VERSION}. ${SCRIPT_TYPE} edition"
echo "expected arguments: ./badapple_v2.sh /path/to/newimage /path/to/oldimage"
echo "add y at the end(3rd argument) if you want to just copy miniOS A and B old to miniOS A and B new, without size checks or miniOS existence checks."
echo "miniOS A and B partitions will be dropped from the oldimage to the newimage."

setup_old_and_new() {
	old_image_LD=$(losetup -f)
	losetup -P "$old_image_LD" "$old_image_path"
	new_image_LD=$(losetup -f)
	losetup -P "$new_image_LD" "$new_image_path"
	echo "old image loop device: ${old_image_LD}"
	echo "new image loop device: ${new_image_LD}"
}

mount_roota() {
	old_mnt=$(mktemp -d)
	new_mnt=$(mktemp -d)
	echo "$old_mnt"
	mount -o ro "${old_image_LD}p3" "$old_mnt"
	mount -o ro "${new_image_LD}p3" "$new_mnt"
}

cleanup() {
	local exit=$1
	local unlink_loops=$2
	local umount_roota=$3
	if [ -n "$umount_roota" ]; then
		umount "$old_mnt"
		umount "$new_mnt"
	fi
	if [ -n "$unlink_loops" ]; then
		losetup -d "$old_image_LD"
		losetup -d "$new_image_LD"
	fi
	if [ -n "$exit" ]; then
		exit
	fi
}

check_minios_presence(){
	MINIOS_OLD=0
	MINIOS_NEW=0
	if [ -f "$old_mnt/usr/sbin/write_gpt.sh" ]; then
		grep -q "MINIOS" "$old_mnt/usr/sbin/write_gpt.sh" && MINIOS_OLD=1
	else
		echo "write_gpt.sh does not exist on the old image. fatal error. cleaning up and exiting."
		cleanup "y" "y" "y"
	fi
	if [ -f "$new_mnt/usr/sbin/write_gpt.sh" ]; then
		grep -q "MINIOS" "$new_mnt/usr/sbin/write_gpt.sh" && MINIOS_NEW=1
	else
		echo "write_gpt.sh does not exist on the new image. fatal error. cleaning up and exiting."
		cleanup "y" "y" "y"
	fi
	if [ "$MINIOS_OLD" -eq 0 ]; then
		echo "minios does not exist on the old recovery image. fatal. cleaning up and exiting."
		cleanup "y" "y" "y"
	fi
	if [ "$MINIOS_NEW" -eq 0 ]; then
		echo "minios does not exist on the new recovery image. fatal. cleaning up and exiting."
		cleanup "y" "y" "y"
	fi
	echo "miniOS exists on the old and new partitions. continuing..."
	cleanup "" "" "y"
}

minios_check_equal_size() {
	# hardcode A as p9 and B as p10
	# lets check all A and B on old and new.
	miniA_old=$(mktemp)
	miniB_old=$(mktemp)
	miniA_new=$(mktemp)
	miniB_new=$(mktemp)
	dd if="${old_image_LD}p9" of="${miniA_old}" > /dev/null 2>&1
	dd if="${old_image_LD}p10" of="${miniB_old}" > /dev/null 2>&1
	dd if="${new_image_LD}p9" of="${miniA_new}" > /dev/null 2>&1
	dd if="${new_image_LD}p10" of="${miniB_new}" > /dev/null 2>&1
	miniA_old_size=$(wc -c "$miniA_old" | awk '{print $1}')
	miniB_old_size=$(wc -c "$miniB_old" | awk '{print $1}')
	miniA_new_size=$(wc -c "$miniA_new" | awk '{print $1}')
	miniB_new_size=$(wc -c "$miniB_new" | awk '{print $1}')
	if [[ $miniA_old_size -eq $miniB_old_size && $miniB_old_size -eq $miniA_new_size && $miniA_new_size -eq $miniB_new_size ]]; then
    	echo "all sizes are equal. check passed."
	else
		echo "not all sizes are equal. this is a fatal error. (how did this even happen??)"
		cleanup "y" "y" "y"
	fi
	rm "$miniA_old" "$miniB_old" "$miniA_new" "$miniB_new"
}

final_copy() {
	# finally, we copy over the old p9 and p10 into the new p9 and p10
	dd if="${old_image_LD}p9" of="${new_image_LD}p9" conv=notrunc > /dev/null 2>&1
	dd if="${old_image_LD}p10" of="${new_image_LD}p10" conv=notrunc > /dev/null 2>&1
}

main() {
	if [ -z "$new_image_path" ]; then
		echo "new image path unspecified. fatal"
		exit
	fi
	if [ -z "$old_image_path" ]; then
		echo "old image path unspecified. fatal"
		exit
	fi
	if [ -n "$no_checks" ]; then
		setup_old_and_new
		cleanup "" "y"
		echo "script finished successfully."
		exit
	else
		setup_old_and_new
		mount_roota
		check_minios_presence
		minios_check_equal_size # a just in case check. the size should always be equal.
		final_copy
		cleanup "" "y"
		echo "script finished successfully."
		exit
	fi
}

no_checks=$3
old_image_path=$2
new_image_path=$1
main
