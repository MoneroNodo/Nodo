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
OLD_TAG="${1:-$(getvar "versions.names.monero")}"
#Error Log:
touch "$DEBUG_LOG"

#Check for updates
project="monero-project"
repo="Monero"
githost="github.com librejo.monerodevs.org"
commit_type="release"  # [tag|release]
get_latest_tag "${project}" "${repo}" "${githost}" "${commit_type}"

showtext "Building Monero..."

{
	if [ ! -d monero ]; then
		tries=0
		until git clone --recursive https://"${githost}"/"${project}"/"${repo}" monero; do
			sleep 1
			tries=$((tries + 1))
			if [ $tries -ge 5 ]; then
				exit 1
			fi
		done
	fi
	cd monero || exit 1
	if [ ! $(git remote -v | grep "${githost}") ]; then
		git remote set-url origin https://"${githost}"/"${project}"/"${repo}"
	fi
	git reset --hard
	git pull
	git checkout "$RELEASE"
	git submodule update --init --force
	# Cleanup build dir
	[ -d build/release ] && rm -rf build/release
	USE_DEVICE_TREZOR=OFF USE_SINGLE_BUILDDIR=1 make -j"$(nproc --ignore=2)" || exit 1
	services-stop monerod
	cp build/release/bin/monero* /home/nodo/bin/ || exit 1
	services-start monerod
	putvar "versions.monero" "$RELEASE" || exit 1
	putvar "versions.names.monero" "$_NAME"
} 2>&1 | tee -a "$DEBUG_LOG"

# Monero codebase needs to stay because LWS depends on it
