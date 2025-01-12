#!/bin/bash

UPD="$(jq -r '.config.autoupdate.pay' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	return 0
fi

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
cd /home/nodo || exit 1

OLD_VERSION_EXP="${1:-$(getvar "versions.pay")}"

RELEASE=$(gitlab_get_tag_commit "moneropay" "moneropay")
#RELEASE=2d8478c

if [ -z "$RELEASE" ] && [ -z "$FIRSTINSTALL" ]; then # Release somehow not set or empty
	showtext "Failed to check for update for MoneroPay"
	exit 0
fi

if [ "$RELEASE" == "$OLD_VERSION_EXP" ]; then
	showtext "No update for MoneroPay"
	exit 0
fi

touch "$DEBUG_LOG"

{
	tries=0
	if [ -d moneropay ]; then
		rm -rf /home/nodo/moneropay
	fi
	until git clone -b master https://gitlab.com/moneropay/moneropay; do
		sleep 1
		tries=$((tries + 1))
		if [ $tries -ge 5 ]; then
			exit 1
		fi
	done
	cd moneropay || exit
	apt install -t bookworm-backports --upgrade golang-go
	git checkout "$RELEASE"
	go build -o moneropay cmd/moneropay/main.go || exit 1
	putvar "versions.exp" "$RELEASE" || exit 1
	cp moneropay /home/nodo/bin/ || exit 1
	cp -r db /home/nodo/execScripts/ || exit 1
	cd || exit
	rm -rf /home/nodo/moneropay
} 2>&1 | tee -a "$DEBUG_LOG"

