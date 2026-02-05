#!/bin/bash
set -e

SCRIPT_VERSION="0.3"
SCRIPT_TYPE="beta" # can be stable, beta, test, PoC

echo "welcome to the badapple v2 builder."
echo "version v${SCRIPT_VERSION}. ${SCRIPT_TYPE} edition"
echo "expected arguments: sudo ${0} /path/to/newimage /path/to/oldimage"
echo "add y at the end(3rd argument) if you want to just copy miniOS A and B old to miniOS A and B new, without size checks or miniOS existence checks."
echo "miniOS A(p9) and B(p10) partitions will be dropped from the oldimage to the newimage. the newimage should be the newer crOS ver image, the oldimage should be the older crOS ver image that has BadApple unpatched."

old_image_ld=""
new_image_ld=""

cleanup(){
	local roota_unmount=false
	local unlink_loops=false
	local do_exit=false
	for arg in "$@"; do
		case $arg in
			"--roota_unmount")
				roota_unmount=true
				;;
			"--unlink_loops")
				unlink_loops=true
				;;
			"--exit")
				do_exit=true
				;;
			*)
				echo "invalid cleanup option, '${arg}' specified. exiting for safety."
				exit
				;;
		esac
	done
	if $roota_unmount; then
		umount "$old_mp"
		umount "$new_mp"
	fi
	if $unlink_loops; then
		losetup -d "$old_image_ld"
		losetup -d "$new_image_ld"
	fi
	if $do_exit; then
		exit
	fi
			
}

setup_ld(){
	# old image 
	old_image_ld=$(losetup -f)
	losetup -P "$old_image_ld" "$old_image_path"
	# new image
	new_image_ld=$(losetup -f)
	losetup -P "$new_image_ld" "$new_image_path"
	# echo final LDs
	echo "old image loop dev on $old_image_ld"
	echo "new image loop dev on $new_image_ld"
}

mount_roota(){
	old_mp=$(mktemp -d)
	new_mp=$(mktemp -d)
	mount -o ro "${old_image_ld}p3" "$old_mp"
	mount -o ro "${new_image_ld}p3" "$new_mp"
}

check_minios_presence(){
	MINIOS_OLD=0
	MINIOS_NEW=0
	if [ -f "$old_mp/usr/sbin/write_gpt.sh" ]; then
		grep -q "MINIOS" "$old_mp/usr/sbin/write_gpt.sh" && MINIOS_OLD=1
	else
		echo "write_gpt.sh does not exist on the old image. fatal error. cleaning up and exiting."
		cleanup "--roota_unmount" "--unlink_loops" "--exit"
	fi
	if [ -f "$new_mp/usr/sbin/write_gpt.sh" ]; then
		grep -q "MINIOS" "$new_mp/usr/sbin/write_gpt.sh" && MINIOS_NEW=1
	else
		echo "write_gpt.sh does not exist on the new image. fatal error. cleaning up and exiting."
		cleanup "--roota_unmount" "--unlink_loops" "--exit"
	fi
	if [ "$MINIOS_OLD" -eq 0 ] || [ "$MINIOS_NEW" -eq 0 ]; then
		echo "minios does not exist on the old recovery image. fatal. cleaning up and exiting."
		cleanup "--roota_unmount" "--unlink_loops" "--exit"
	fi
	echo "miniOS exists on the old and new partitions. continuing..."
	cleanup "--roota_unmount"
}

minios_check_equal_size(){
	# hardcode A as p9 and B as p10
	# lets check all A and B on old and new.
	miniA_old_size=$(blockdev --getsize64 "${old_image_ld}p9")
	miniB_old_size=$(blockdev --getsize64 "${old_image_ld}p10")
	miniA_new_size=$(blockdev --getsize64 "${new_image_ld}p9")
	miniB_new_size=$(blockdev --getsize64 "${new_image_ld}p10")

	sizes=($miniA_old_size $miniB_old_size $miniA_new_size $miniB_new_size)
	for ((i=1; i<${#sizes[@]}; i++)); do
		if [[ ${sizes[i]} -ne ${sizes[0]} ]]; then
			echo "not all sizes are equal. this is a fatal error. (how did this even happen??)"
			cleanup "--roota_unmount" "--unlink_loops" "--exit"
			exit # exit if somehow not exited, should never reach this.
		fi
	done
	echo "sizes equal. check passed."
}

final_copy(){
	# finally, we copy over the old p9 and p10 into the new p9 and p10
	for part_number in "p9" "p10"; do
		dd if="${old_image_ld}${part_number}" of="${new_image_ld}${part_number}" conv=notrunc > /dev/null 2>&1
	done
}

check_root(){
	if [[ $EUID -ne 0 ]]; then
 		echo "script not running as root. fatal"
   		exit
	fi
}

main(){
	if [ -z "$new_image_path" ]; then
		echo "new image path unspecified. fatal"
		exit
	fi
	if [ -z "$old_image_path" ]; then
		echo "old image path unspecified. fatal"
		exit
	fi
	if [ -n "$no_checks" ]; then
		setup_ld
  		final_copy
		cleanup "--unlink_loops"
		echo "script finished successfully."
		exit
	else
		setup_ld
		mount_roota
		check_minios_presence
		minios_check_equal_size # a just in case check. the size should always be equal.
		final_copy
		cleanup "--unlink_loops"
		echo "script finished successfully."
		exit
	fi
}

no_checks=$3
old_image_path=$2
new_image_path=$1
check_root
main
