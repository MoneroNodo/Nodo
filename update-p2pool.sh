#!/bin/bash

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
cd /home/nodo || exit 1

OLD_VERSION_P2POOL="${1:-$(getvar "versions.p2pool")}"

RELEASE=$(get_release_commit "SChernykh" "p2pool")

if [ -z "$RELEASE" ] && [ -z "$FIRSTINSTALL" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for Monero p2pool"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION_P2POOL" ]; then
	showtext "No update for Monero p2pool"
	exit 0
fi

touch "$DEBUG_LOG"

showtext "
####################
Start update-p2pool.sh script $(date)
####################
"

showtext "Building Monero p2pool..."

{
	git clone --recursive -b master https://github.com/SChernykh/p2pool.git
	cd p2pool || exit
	git reset --hard HEAD
	git pull --rebase
	git checkout "$RELEASE"
	mkdir build
	cd build || exit
	cmake ..
	make -j"$(nproc --ignore=2)" || exit 1
	cp p2pool /home/nodo/bin/ || exit 1
	chmod a+x /home/nodo/bin/p2pool || exit 1
	putvar "versions.p2pool" "$RELEASE" || exit 1
	cd || exit
	rm -rf /home/nodo/p2pool
} 2>&1 | tee -a "$DEBUG_LOG"

#
##End debug log
showtext "
####################
End update-p2pool.sh script $(date)
####################"
