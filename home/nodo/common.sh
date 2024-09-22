#!/bin/bash
#Common variables and functions

_APTGET='DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages'
DEBUG_LOG=debug.log
CONFIG_FILE=/home/nodo/variables/config.json
XMRPARTLABEL="NODO_BLOCKCHAIN"

gitlab_get_tag_commit() {
	project="$(printf '%s' "$1" | sed 's/./\L&/g')"
	repo="$(printf '%s' "$2" | sed 's/./\L&/g')"
	githost="${3:-gitlab.com}"
	tag=$(curl -ls "https://$githost/api/v4/projects/$project%2F$repo/repository/tags" | jq -r '.[0].commit.id')
	printf '%s' "$tag"
}

gitlab_get_release_commit() {
	project="$(printf '%s' "$1" | sed 's/./\L&/g')"
	repo="$(printf '%s' "$2" | sed 's/./\L&/g')"
	githost="${3:-gitlab.com}"
	tag=$(curl -ls "https://$githost/api/v4/projects/$project%2F$repo/releases" | jq -r '.[0].commit.id')
	printf '%s' "$tag"
}

get_tag_commit() {
	project="$1"
	repo="$2"
	tag=$(curl -ls "https://api.github.com/repos/$project/$repo/tags" | jq -r '.[0].commit.sha')
	printf '%s' "$tag"
}

get_release_commit() {
	project="$1"
	repo="$2"
	tag=$(curl -ls "https://api.github.com/repos/$project/$repo/releases/latest" | jq -r '.tag_name')
	{
		read -r type
		read -r tag_sha

		if [ "$type" == "commit" ]; then
			printf "%s" "$tag_sha"
		else
			sha=$(curl -s "https://api.github.com/repos/$project/$repo/git/tags/$tag_sha" | jq -r '.object.sha')
			printf "%s" "$sha"
		fi
	} < <(curl -s "https://api.github.com/repos/$project/$repo/git/ref/tags/$tag" |
		jq -r '.object.type,.object.sha')
	}

get_ip() {
	ip route get 1.1.1.1 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'
}

check_connection() {
	touse="$(ip r | grep default | cut -d ' ' -f 3)"
	for f in $touse; do
		if ping -q -w 1 -c 1 "$f" >/dev/null; then
			return 0
		fi
	done
	return 1
}

ENCRYPT_FS="0"

setup_drive() {
	blockdevice="/dev/$1"
	fstype="$2"

	#unmount just in case
	for f in $(lsblk -o KNAME | grep -e "$1\\d\?"); do
		umount -vf "/dev/$f"
	done
	#format
	wipefs --all "/dev/$1"
	#create table & part
	sleep 1
	if [ "$ENCRYPT_FS" != "0" ]; then
		true
		# TODO encrypt
	else
		parted --script "$blockdevice" mklabel gpt mkpart primary 1MiB 100% name 1 "$XMRPARTLABEL"
		sleep 1
		#create fs
		mkfs."$fstype" -f "${blockdevice}p1"

	fi
	sleep 1
	#get uuid from block device
	uuid=$(blkid | grep "$1"p1 | sed 's/.*\sUUID="\([a-z0-9\-]\+\)".*/\1/g')
	#append new partition to fstab
	sed "/^UUID=$uuid/d" /etc/fstab
	#add to fstab
	printf "\nUUID=%s\t/media/monero\t%s\tdefaults,noatime,nofail,x-systemd.device-timeout=3\t0\t0" "$uuid" "$fstype" | tee -a /etc/fstab
	#create mountpoint
	mkdir -p /media/monero
	#mount
	mount -v "UUID=$uuid"
	#correct owner
	chown monero:monero -R /media/monero
}

getip() {
	hostname -I | awk '{print $1}'
}

getvar() {
	jq -r ".config.$1" "$CONFIG_FILE"
}

putvar() {
	# Very cringe, I know
	re='^[+-]?[0-9]+([.][0-9]+)?$'
	if [[ $2 =~ $re ]]; then
		contents=$(jq --argjson var "$2" ".config.$1 = \$var" "$CONFIG_FILE")
	else
		contents=$(jq --argjson var "\"$2\"" ".config.$1 = \$var" "$CONFIG_FILE")
	fi
	if [ -n "$contents" ]; then
		echo -E "$contents" >"$CONFIG_FILE"
	fi
}

showtext() {
	log "$*"
	echo -e "\e[32m$*\e[0m"
}

log() {
	echo "$*" >>"$DEBUG_LOG"
}

services="monerod block-explorer monero-lws webui xmrig"
services-stop() {
	for f in $services; do
		systemctl stop "$f".service
	done
}

services-start() {
	for f in $services; do
		if systemctl is-enabled "$f".service; then
			systemctl start "$f".service
		fi
	done
}

export -f log
export -f showtext
export DEBUG_LOG
export CONFIG_FILE
