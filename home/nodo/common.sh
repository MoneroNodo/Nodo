#!/bin/bash
#Common variables and functions

_APTGET='DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages'
DEBUG_LOG=/root/debug.log
CONFIG_FILE=/home/nodo/variables/config.json
XMRPARTLABEL="NODO_BLOCKCHAIN"

gitlab_get_tag_commit_name() {
	project="$(printf '%s' "$1" | sed 's/./\L&/g')"
	repo="$(printf '%s' "$2" | sed 's/./\L&/g')"
	githost="${3:-gitlab.com}"
	tag=$(curl -ls "https://$githost/api/v4/projects/$project%2F$repo/repository/tags" | jq -r '.[0].commit.id, .[0].name')
	printf '%s' "$tag"
}

gitlab_get_release_commit_name() {
	project="$(printf '%s' "$1" | sed 's/./\L&/g')"
	repo="$(printf '%s' "$2" | sed 's/./\L&/g')"
	githost="${3:-gitlab.com}"
	tag=$(curl -ls "https://$githost/api/v4/projects/$project%2F$repo/releases" | jq -r '.[0].commit.id, .[0].name')
	printf '%s' "$tag"
}

gitlab_get_tag_name_from_commit() {
	project="$1"
	repo="$2"
	commit="$3"
	githost="${4:-gitlab.com}"
	tag="$(curl -ls "https://$githost/api/v4/projects/$project%2F$repo/releases" | jq -r "$(printf '.[] | select(.commit.id | contains("%s")) | .name' "$commit")")"
	printf '%s' "$tag"
}

get_tag_name_from_commit() {
	project="$1"
	repo="$2"
	commit="$3"
	tag="$(curl -ls "https://api.github.com/repos/$project/$repo/tags" | jq -r "$(printf '.[] | select(.commit.sha | contains("%s")) | .name' "$commit")")"
	printf '%s' "$tag"
}

get_tag_commit_name() {
	project="$1"
	repo="$2"
	tag=$(curl -ls "https://api.github.com/repos/$project/$repo/tags" | jq -r '.[0].commit.sha, .[0].name')
	printf '%s' "$tag"
}

get_release_commit_name() {
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
		printf "\n%s" "$tag"
	} < <(curl -s "https://api.github.com/repos/$project/$repo/git/ref/tags/$tag" |
		jq -r '.object.type,.object.sha')
}

get_release_name() {
	get_release_commit_name "$@" | tail -n1
}

get_tag_name() {
	get_tag_commit_name "$@" | tail -n1
}

gitlab_get_tag_name() {
	gitlab_get_tag_commit_name "$@" | tail -n1
}

gitlab_get_release_name() {
	gitlab_get_release_commit_name "$@" | tail -n1
}

get_release_commit() {
	get_release_commit_name "$@" | head -n1
}

get_tag_commit() {
	get_tag_commit_name "$@" | head -n1
}

gitlab_get_tag_commit() {
	gitlab_get_tag_commit_name "$@" | head -n1
}

gitlab_get_release_commit() {
	gitlab_get_release_commit_name "$@" | head -n1
}

get_ip() {
	ip route get 9.9.9.9 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}'
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

check_update_tag() {
	tries=0
	maxtries=3
	while [ -z "$RELEASE" ] || [ "$RELEASE" == "null" ]; do
		if [ "${tries}" -ge "${maxtries}" ]; then
			showtext "[${tries}/${maxtries}] Update check failed for $2"
			exit 0
		fi

		# Check for updates
		tries=$((tries+1))
		showtext "[${tries}/${maxtries}] Checking updates for $2"
		if [ "$2" == "Monero" ]; then  # strictly use releases for monero
			RELNAME=$(get_release_commit_name "$1" "$2")
		elif [ "$3" == "github.com" ]; then
			RELNAME=$(get_tag_commit_name "$1" "$2")
		elif [ "$3" == "gitlab.com" ]; then
			RELNAME=$(gitlab_get_tag_commit_name "$1" "$2")
		fi
		RELEASE=$(printf '%s' "$RELNAME" | head -n1)
		_NAME=$(printf '%s' "$RELNAME" | tail -n1)
		echo "${RELEASE}"
		echo "${_NAME}"
		sleep 2
	done

	if [[ "$OLD_VERSION" == "$RELEASE" ]]; then
		showtext "No update for $2"
		exit 0
	fi
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

services="monerod monero-lws monero-wallet-rpc moneropay"
services-stop() {
	for f in ${1:-$services}; do
		sudo systemctl stop "$f".service
	done
}

services-start() {
	for f in ${1:-$services}; do
		if systemctl is-enabled "$f".service; then
			sudo systemctl start "$f".service
		fi
	done
}

export -f log
export -f showtext
export DEBUG_LOG
export CONFIG_FILE
