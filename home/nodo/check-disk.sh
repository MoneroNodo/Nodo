#!/bin/bash

# shellcheck source=home/nodo/common.sh
. /root/nodo/home/nodo/common.sh

_found() {
	mkdir -p /media/monero
	mount -v /dev/nvme0n1p1 /media/monero
	if ! swapon --show | grep -q '/media/monero/swap'; then
		makeswap
	fi
	services-start
	exit 0
}

_nossd() {
	exit 0
}

uuid="" # TODO some way to get uuid if LUKS
# If not found then search for regular
[ -z "$uuid" ] && uuid="$(grep media\\/monero /etc/fstab | cut -d"	" -f1 | cut -d= -f2 | head -n1)" # Ugly

_blkid=$(blkid)
echo "$_blkid" | grep -q "LABEL=$XMRPARTLABEL" && _found # SSD found
echo "$_blkid" | grep -q "$uuid" && _found # SSD found
echo "$_blkid" | grep -q '/dev/nvme0n1p1: UUID=[^ ]\+ BLOCK_SIZE="512" TYPE="xfs"' && _found # SSD found
echo "$_blkid" | grep -q "nvme" || _nossd # no SSD found at all, nothing to format


echo "SSD not formatted"

echo "Auto formatting in 5 seconds"
sleep 5 && . /root/nodo/home/nodo/common.sh && bash /root/nodo/home/nodo/setup-drive.sh
