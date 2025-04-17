#!/bin/bash

UPD="$(jq -r '.config.autoupdate.monero' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic monero updates disabled"
	exit 0
fi

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

cd /home/nodo || exit 1

[ -d monero.retain ] && rm -rf monero.retain

OLD_VERSION="${1:-$(getvar "versions.monero")}"
#Error Log:
touch "$DEBUG_LOG"

RELNAME=$(get_release_commit_name "monero-project" "monero")
RELEASE="$(printf '%s' "$RELNAME" | head -n1)"
_NAME="$(printf '%s' "$RELNAME" | tail -n1)"

if [ -z "$RELEASE" ] && [ -z "$FIRSTINSTALL" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for Monero"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION" ]; then
	showtext "No update for Monero"
	exit 0
fi

showtext "Building Monero..."

{
	if [ ! -d monero ]; then
		tries=0
		until git clone --recursive https://github.com/monero-project/monero.git; do
			sleep 1
			tries=$((tries + 1))
			if [ $tries -ge 5 ]; then
				exit 1
			fi
		done
	fi
	cd monero || exit 1
	git reset --hard
	git pull
	git checkout "$RELEASE"
	git submodule update --init --force
	[ -d build/release ] && rm -rf build/release
	USE_DEVICE_TREZOR=OFF USE_SINGLE_BUILDDIR=1 make -j"$(nproc --ignore=2)" || exit 1
	services-stop monerod
	cp build/release/bin/monero* /home/nodo/bin/ || exit 1
	services-start monerod
	putvar "versions.monero" "$RELEASE" || exit 1
	putvar "versions.names.monero" "$_NAME"
} 2>&1 | tee -a "$DEBUG_LOG"

# Monero codebase needs to stay because LWS depends on it
