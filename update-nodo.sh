#!/bin/bash

UPD="$(jq -r '.config.autoupdate.nodo' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic nodo updates disabled"
	exit 0
fi

#Create/ammend debug file for handling update errors:
#shellcheck source=home/nodo/common.sh
. /root/nodo/home/nodo/common.sh || exit 1
OLD_VERSION="${1:-$(getvar "versions.nodo")}"
OLD_TAG="${1:-$(getvar "versions.names.nodo")}"
#Error log
touch "$DEBUG_LOG"

#Check for updates
project="moneronodo"
repo="Nodo"
githost="github.com"
commit_type="tag"  # [tag|release]
get_latest_tag "${project}" "${repo}" "${githost}" "${commit_type}"
_NAME="nodo-${_NAME}"

_cwd=/root/nodo

cd /root || exit
tries=0
if [ -d "${_cwd}" ]; then
	cd nodo || exit 1
	have_remote=$(git remote -v | grep "${githost}")
	if [ -z "${have_remote}"  ]; then
		git remote set-url origin https://"${githost}"/"${project}"/"${repo}"
	fi
	git pull
else
	until git clone https://"${githost}"/"${project}"/"${repo}" "${_cwd}"; do
	sleep 1
	tries=$((tries + 1))
	if [ $tries -ge 5 ]; then
		exit 1
	fi
done
	cd nodo || exit 1
fi

#Update functions and force a recheck if release hash is unset
if [ -z "${RELEASE}" ]; then
	#Activate updated functions
	. /root/nodo/home/nodo/common.sh
	#Check for updates
	get_latest_tag "${project}" "${repo}" "${githost}" "${commit_type}" || echo "Failed to set version"; exit 1
	_NAME="nodo-${_NAME}"
fi

#Reset repo
git reset --hard "$RELEASE"

#Backup User values
showtext "Creating backups of any settings you have customised"
#home dir
#variables dir
_v=/home/nodo/variables
mv "${_v}"/config.json "${_v}"/config_retain.json
showtext "User configuration saved"

#Install Update
showtext "setup-nodo.sh..."
bash "${_cwd}"/setup-nodo.sh

#Merge / restore variables
bash "${_cwd}"/configure-nodo.sh

#Update system version number to new one installed
{
	showtext "Updating system version number..."
	putvar "versions.nodo" "$RELEASE"
	putvar "versions.names.nodo" "$_NAME"
	#ubuntu /dev/null odd requiremnt to set permissions
	chmod 777 /dev/null
} 2>&1 | tee -a "$DEBUG_LOG";
