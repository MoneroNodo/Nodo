#!/bin/bash
# Try to get system to a working state again
# options:
# PURGE_BLOCKCHAIN: remove the lmdb folder, forcing a complete resync
# REPAIR_FILESYSTEM: run XFS repair on the SSD

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

# Run an update just to be sure
apt-get update --fix-missing -y

# Force Apt to look for and correct any missing dependencies or broken packages when you attempt to install the offending package again. This will install any missing dependencies and repair existing installs
apt-get install -fy

# Reconfigure any broken or partially configured packages
dpkg --configure -a

apt clean

apt update

services-stop

while :; do
	case "$1" in
	'-purge')
		PURGE_BLOCKCHAIN=1
		;;
	'-repair')
		REPAIR_FILESYSTEM=1
		;;
	*)
		break
		;;
	esac
	shift
done

if [ -n "$REPAIR_FILESYSTEM" ]; then
	# awfully crude way to find SSD
	uuid=$(lsblk -o UUID,MOUNTPOINT | grep nodo | awk '{print $1}')
	device="/dev/disk/by-uuid/$uuid"
	umount "$uuid"
	xfs_repair "$device"
	mount "$uuid"
fi

# if $PURGE_BLOCKCHAIN is set (to anything), purge the blockchain
if [ -n "$PURGE_BLOCKCHAIN" ]; then
	rm -rf "$(getvar "data_dir")"/lmdb
fi

services-start

