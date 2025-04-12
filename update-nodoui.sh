#!/bin/bash

UPD="$(jq -r '.config.autoupdate.nodo' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic nodoui updates disabled"
	exit 0
fi

#(1) Define variables and updater functions
#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
cd /home/nodo || exit 1
OLD_VERSION_EUI="${1:-$(getvar "versions.nodoui")}"


RELNAME=$(get_tag_commit_name "moneronodo" "nodoui")
RELEASE="$(printf '%s' "$RELNAME" | head -n1)"
_NAME="$(printf '%s' "$RELNAME" | tail -n1)"

if [ -z "$RELEASE" ] && [ -z "$FIRSTINSTALL" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for Nodo UI"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION_EUI" ]; then
	showtext "No update for Nodo UI"
	exit 0
fi

touch "$DEBUG_LOG"

showtext "
####################
Start setup-update-nodoui.sh script $(date)
####################
"

##Delete old version
showtext "Delete old version"
showtext "Downloading Nodo UI"
{
	remove() {
		rm -rf /home/nodo/nodoui
	}
	trap remove INT HUP EXIT
	git clone --recursive https://github.com/moneronodo/nodoui.git
	cd nodoui || exit 1
	git reset --hard HEAD
	git checkout "$RELEASE"
	git pull
	showtext "Building Nodo UI"
	bash ./install.sh || exit 1
	putvar "versions.nodoui" "$RELEASE" || exit 1
	putvar "versions.names.nodoui" "$_NAME"
	cd || exit
	remove
} 2>&1 | tee -a "$DEBUG_LOG"
cd || exit 1
##End debug log
showtext "Nodo UI Updated
####################
End setup-update-nodoui.sh script $(date)
####################"
