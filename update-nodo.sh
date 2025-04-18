#!/bin/bash

UPD="$(jq -r '.config.autoupdate.nodo' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic nodo updates disabled"
	exit 0
fi

#Create/ammend debug file for handling update errors:
#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
OLD_VERSION_NODO="${1:-$(getvar "versions.nodo")}"
touch "$DEBUG_LOG"

RELNAME="$(get_tag_commit_name "moneronodo" "nodo")"

RELEASE="$(printf '%s' "$RELNAME" | head -n1)"
_NAME="$(printf '%s' "$RELNAME" | tail -n1)"
_NAME="nodo-${_NAME}" # print as a string so the version is parsed properly

if [ -z "$RELEASE" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for Nodo"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION_NODO" ]; then
	showtext "No update for Nodo"
	exit 0
fi

_cwd=/root/nodo

cd /root || exit
tries=0
if [ -d "${_cwd}" ]; then
	cd nodo || exit 1
	git pull
else
	until git clone https://github.com/moneronodo/nodo "${_cwd}"; do
	sleep 1
	tries=$((tries + 1))
	if [ $tries -ge 5 ]; then
		exit 1
	fi
done
	cd nodo || exit 1
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

showtext "Merge config.json"
if jq -s '.[0] * .[1] | {config: .config}' "${_v}"/config.json "${_v}"/config_retain.json > "${_v}"/config.merge.json; then
	cp -f "${_v}"/config.merge.json "${_v}"/config.json
else
	cp -f "${_v}"/config_retain.json "${_v}"/config.json
fi

chown nodo:nodo "${_v}"/config.json

showtext "User configuration restored"

#Update system version number to new one installed
{
	showtext "Updating system version number..."
	putvar "versions.nodo" "$RELEASE"
	putvar "versions.names.nodo" "$_NAME"
	#ubuntu /dev/null odd requiremnt to set permissions
	chmod 777 /dev/null
} 2>&1 | tee -a "$DEBUG_LOG";
