#!/bin/bash
#(1) Define variables and updater functions
#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
OLD_VERSION_LWS="${1:-$(getvar "versions.lws")}"

RELEASE="$(curl -fs https://raw.githubusercontent.com/MoneroNodo/Nodo/master/release-monero-lws.txt)"
#RELEASE="release-v0.18" # TODO remove when live

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
rm -rf /home/nodo/monero-lws 2>&1 | tee -a "$DEBUG_LOG"
showtext "Downloading VTNerd Monero-LWS"
{
	git clone --recursive https://github.com/vtnerd/monero-lws.git
	cd monero-lws || exit 1
	# Temporary band-aid as newer commits don't seem to want to build
	git checkout master
	git pull
	git reset --hard e09d3d57e9f88cb47702976965bd6e1ed813c07f
	mkdir build
	cd build || exit 1
	cmake -DMONERO_SOURCE_DIR=/home/nodo/monero -DMONERO_BUILD_DIR=/home/nodo/monero/build/release ..
	showtext "Building VTNerd Monero-LWS"
	make -j"$(nproc --ignore=2)" && \
		cp src/monero-lws* /home/nodo/bin/ && \
		putvar "versions.lws" "$RELEASE"
} 2>&1 | tee -a "$DEBUG_LOG"
cd || exit 1
