#!/bin/bash

# shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

uuid="" # TODO some way to get uuid if LUKS
# If not found then search for regular
[ -z "$uuid" ] && uuid="$(grep media\\/monero /etc/fstab | cut -d" " -f1 | cut -d= -f2)" # Ugly

_blkid=$(blkid)
echo "$_blkid" | grep -q "LABEL=$XMRPARTLABEL" && exit 0 # SSD found
echo "$_blkid" | grep -q "$uuid" && exit 0 # SSD found
echo "$_blkid" | grep -q "nvme" || exit 0 # no SSD found at all, nothing to format


echo "SSD not formatted"

echo "Auto formatting in 5 seconds"
sleep 5 && . /home/nodo/common.sh && bash setup-drive.sh
