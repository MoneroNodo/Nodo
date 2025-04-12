#!/bin/bash

UPD="$(jq -r '.config.autoupdate.monero' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	return 0
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

[ -f /media/monero/banlist.txt ] || bash /home/nodo/update-banlists.sh

{
	test -d monero.new && rm -rf monero.new
	tries=0
	until git clone --recursive https://github.com/monero-project/monero.git monero.new; do
		sleep 1
		tries=$((tries + 1))
		if [ $tries -ge 5 ]; then
			exit 1
		fi
	done
	rm -rf monero
	mv monero.new monero
	cd monero || exit 1
	git checkout "$RELEASE"
	git submodule update --init --force
	USE_DEVICE_TREZOR=OFF USE_SINGLE_BUILDDIR=1 make -j"$(nproc --ignore=2)" || exit 1
	services-stop monerod
	cp build/release/bin/monero* /home/nodo/bin/ || exit 1
	chmod a+x /home/nodo/bin/monero* || exit 1
	services-start monerod
	putvar "versions.monero" "$RELEASE" || exit 1
	putvar "versions.names.monero" "$_NAME"
} 2>&1 | tee -a "$DEBUG_LOG"

# Monero codebase needs to stay because LWS depends on it
