#!/bin/bash

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
cd /home/nodo || exit 1

OLD_VERSION_XMRIG="${1:-$(getvar "versions.xmrig")}"

RELEASE=$(get_release_commit "xmrig" "xmrig")
#RELEASE="release-v0.18" # TODO remove when live

if [ -z "$RELEASE" ] && [ -z "$FIRSTINSTALL" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for Monero xmrig"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION_XMRIG" ]; then
	showtext "No update for Monero xmrig"
	exit 0
fi

touch "$DEBUG_LOG"

#(1) Define variables and updater functions

rm -rf /home/nodo/xmrig/
showtext "Building Monero xmrig..."

{
	git clone -b master https://github.com/xmrig/xmrig.git
	cd xmrig || exit
	git reset --hard HEAD
	git pull --rebase
	git checkout "$RELEASE"
	mkdir build
	cd build || exit
	cmake ..
	make -j"$(nproc --ignore=2)" && \
		cp xmrig /home/nodo/bin/ && \
		chmod a+x /home/nodo/bin/xmrig && \
		putvar "versions.xmrig" "$RELEASE"
} 2>&1 | tee -a "$DEBUG_LOG"
