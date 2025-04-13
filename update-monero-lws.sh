#!/bin/bash

UPD="$(jq -r '.config.autoupdate.lws' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic lws updates disabled"
	exit 0
fi

#(1) Define variables and updater functions
#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
OLD_VERSION_LWS="${1:-$(getvar "versions.lws")}"

RELNAME="d8ee984b3c43babbefbb405ae7ebf75b57e85b0c"
RELEASE="$(printf '%s' "$RELNAME" | head -n1)"
_NAME="$(printf '%s' "$RELNAME" | tail -n1)"

if [ -z "$RELEASE" ] && [ -z "$FIRSTINSTALL" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for LWS"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION_LWS" ]; then
	showtext "No update for LWS"
	exit 0
fi

touch "$DEBUG_LOG"

##Delete old version
showtext "Delete old version"
showtext "Downloading VTNerd Monero-LWS"
{
	tries=0
	if [ -d monero-lws ]; then
		rm -rf /home/nodo/monero-lws
	fi
	until git clone --recursive https://github.com/vtnerd/monero-lws.git; do
		sleep 1
		tries=$((tries + 1))
		if [ $tries -ge 5 ]; then
			exit 1
		fi
	done
	cd monero-lws || exit 1
	# Temporary band-aid as newer commits don't seem to want to build
	git checkout d8ee984b3c43babbefbb405ae7ebf75b57e85b0c # TODO remove when lws builds again
	mkdir build
	cd build || exit 1
	cmake -DMONERO_SOURCE_DIR=/home/nodo/monero -DMONERO_BUILD_DIR=/home/nodo/monero/build/release ..
	showtext "Building VTNerd Monero-LWS"
	make -j"$(nproc --ignore=2)" || exit 1
	services-stop monero-lws
	cp src/monero-lws* /home/nodo/bin/ || exit 1
	services-start monero-lws
	putvar "versions.lws" "$RELEASE" || exit 1
	putvar "versions.names.lws" "$_NAME"
	cd || exit
	rm -rf /home/nodo/monero-lws
} 2>&1 | tee -a "$DEBUG_LOG"
cd || exit 1
