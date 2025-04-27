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

OLD_VERSION="${1:-$(getvar "versions.lws")}"
OLD_TAG="${1:-$(getvar "versions.names.lws")}"
#Error Log:
touch "$DEBUG_LOG"

#Check for updates
RELNAME="d8ee984b3c43babbefbb405ae7ebf75b57e85b0c"  # Temporary band-aid as newer commits don't seem to want to build
RELEASE="$(printf '%s' "$RELNAME" | head -n1)"
_NAME="${RELNAME:0:8}"

project="vtnerd"
repo="monero-lws"
githost="github.com"
commit_type="tag"  # [tag|release]
get_latest_tag "${project}" "${repo}" "${githost}" "${commit_type}"

showtext "Building VTNerd Monero-LWS.."

{
	if [ ! -d monero-lws ]; then
		tries=0
		until git clone --recursive https://"${githost}"/"${project}"/"${repo}" monero-lws; do
			sleep 1
			tries=$((tries + 1))
			if [ $tries -ge 5 ]; then
				exit 1
			fi
		done
	fi
	cd monero-lws || exit 1
	have_remote=$(git remote -v | grep "${githost}")
	if [ -z "${have_remote}"  ]; then
		git remote set-url origin https://"${githost}"/"${project}"/"${repo}"
	fi
	git reset --hard
	git pull
	git checkout "$RELEASE"
	submodule update --init --force
	[ -d build ] && rm -rf build
	mkdir build && cd $_ || exit 1
	cmake -DMONERO_SOURCE_DIR=/home/nodo/monero -DMONERO_BUILD_DIR=/home/nodo/monero/build/release .. || exit 1
	make -j"$(nproc --ignore=2)" || exit 1
	services-stop monero-lws
	cp src/monero-lws* /home/nodo/bin/ || exit 1
	services-start monero-lws
	putvar "versions.lws" "$RELEASE" || exit 1
	putvar "versions.names.lws" "$_NAME"
	cd || exit
} 2>&1 | tee -a "$DEBUG_LOG"
cd || exit 1
