#!/bin/bash

UPD="$(jq -r '.config.autoupdate.sshui' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic sshui updates disabled"
	exit 0
fi

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
cd /home/nodo || exit 1

OLD_VERSION="${1:-$(getvar "versions.sshui")}"
OLD_TAG="${1:-$(getvar "versions.names.sshui")}"
#Error log
touch "$DEBUG_LOG"

#Check for updates
project="moneronodo"
repo="sshui"
githost="github.com"
commit_type="release"  # [tag|release]
get_latest_tag "${project}" "${repo}" "${githost}" "${commit_type}"

{
	tries=0
	if [ -d sshui ]; then
		rm -rf /home/nodo/sshui
	fi
	until git clone -b master https://"${githost}"/"${project}"/"${repo}" sshui; do
		sleep 1
		tries=$((tries + 1))
		if [ $tries -ge 5 ]; then
			exit 1
		fi
	done
	cd sshui || exit
	apt install -t bookworm-backports --upgrade golang-go
	git checkout "$RELEASE"
	go build -o sshui cmd/sshui/main.go || exit 1
	putvar "versions.sshui" "$RELEASE" || exit 1
	putvar "versions.names.sshui" "$_NAME"
	cp sshui /home/nodo/bin/ || exit 1
	cd || exit
	rm -rf /home/nodo/sshui
} 2>&1 | tee -a "$DEBUG_LOG"

