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

REFORMAT_ON_FAILURE=${REFORMAT_ON_FAILURE:-1}

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

if [ "$REPAIR_FILESYSTEM" != "" ]; then
	# awfully crude way to find SSD
	uuid=$(lsblk -o UUID,MOUNTPOINT | grep nodo | awk '{print $1}')
	device="/dev/disk/by-uuid/$uuid"
	failcounter=0
	umount "$uuid"
	while :; do
		xfs_repair -e "$device"
		_result=$?
		case $_result in
			1) # runtime error, should be restarted according to manual
				failcounter=$((failcounter+1))
				if [ $failcounter -gt 5 ]; then
					bash /home/nodo/setup-drive.sh
					break 2
				fi
				continue
				;;
			2) # dirty log: mount and unmount, then re-run xfs_repair
				mount "$uuid"
				umount "$uuid"
				continue
				;;
			4) # issues were found and fixed
				break
				;;
			*)
				break
				;;
		esac
		break
	done
fi

# if $PURGE_BLOCKCHAIN is set (to anything), purge the blockchain
if [ "$PURGE_BLOCKCHAIN" != "" ]; then
	rm -rf "$(getvar "data_dir")"/lmdb
fi

services-start
