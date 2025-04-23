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
OLD_VERSION="${1:-$(getvar "versions.nodoui")}"
OLD_TAG="${1:-$(getvar "versions.names.nodoui")}"
#Error log
touch "$DEBUG_LOG"

#Check for updates
project="moneronodo"
repo="NodoUI"
githost="github.com"
commit_type="tag"  # [tag|release]
get_latest_tag "${project}" "${repo}" "${githost}" "${commit_type}"

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
	git clone --recursive https://"${githost}"/"${project}"/"${repo}" nodoui
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
