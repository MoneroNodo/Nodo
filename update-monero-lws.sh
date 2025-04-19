#!/bin/bash

UPD="$(jq -r '.config.autoupdate.lws' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic lws updates disabled"
	exit 0
fi

#(1) Define variables and updater functions
#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

cd /home/nodo || exit 1

OLD_VERSION_LWS="${1:-$(getvar "versions.lws")}"
#Error Log:
touch "$DEBUG_LOG"

#RELNAME=$(get_release_commit_name "vtnerd" "monero-lws")
#RELEASE="$(printf '%s' "$RELNAME" | head -n1)"
RELNAME="d8ee984b3c43babbefbb405ae7ebf75b57e85b0c"  # Temporary band-aid as newer commits don't seem to want to build
RELEASE="${RELNAME:0:8}"
_NAME="$(printf '%s' "$RELNAME" | tail -n1)"

if [ -z "$RELEASE" ] && [ -z "$FIRSTINSTALL" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for LWS"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION_LWS" ]; then
	showtext "No update for LWS"
	exit 0
fi

showtext "Building VTNerd Monero-LWS.."

{
	if [ ! -d monero-lws ]; then
		tries=0
		until git clone --recursive https://github.com/vtnerd/monero-lws.git; do
			sleep 1
			tries=$((tries + 1))
			if [ $tries -ge 5 ]; then
				exit 1
			fi
		done
	fi
	cd monero-lws || exit 1
	git reset --hard
	git pull
	git checkout "$RELEASE"
	submodule update --init --force
	[ -d build ] && rm -rf build
	mkdir build && cd $_ || exit 1
	cmake -DMONERO_SOURCE_DIR=/home/nodo/monero -DMONERO_BUILD_DIR=/home/nodo/monero/build/release ..
	make -j"$(nproc --ignore=2)" || exit 1
	services-stop monero-lws
	cp src/monero-lws* /home/nodo/bin/ || exit 1
	services-start monero-lws
	putvar "versions.lws" "$RELEASE" || exit 1
	putvar "versions.names.lws" "$_NAME"
	cd || exit
} 2>&1 | tee -a "$DEBUG_LOG"
cd || exit 1
