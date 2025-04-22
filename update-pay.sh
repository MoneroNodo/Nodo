#!/bin/bash

UPD="$(jq -r '.config.autoupdate.pay' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ -z "$1" ]; then
	echo "INFO : automatic moneropay updates disabled"
	exit 0
fi

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh
cd /home/nodo || exit 1

OLD_VERSION="${1:-$(getvar "versions.pay")}"
OLD_TAG="${1:-$(getvar "versions.names.pay")}"
#Error log
touch "$DEBUG_LOG"

#Check for updates
project="moneropay"
repo="Moneropay"
githost="gitlab.com"
commit_type="tag"  # [tag|release]
check_update_tag "${project}" "${repo}" "${githost}" "${commit_type}"

{
	tries=0
	if [ -d moneropay ]; then
		rm -rf /home/nodo/moneropay
	fi
	until git clone -b master https://"${githost}"/"${project}"/"${repo}" moneropay; do
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
	putvar "versions.pay" "$RELEASE" || exit 1
	putvar "versions.names.pay" "$_NAME"
	services-stop moneropay
	cp moneropay /home/nodo/bin/ || exit 1
	cp -r db /home/nodo/execScripts/ || exit 1
	services-start moneropay
	cd || exit
	rm -rf /home/nodo/moneropay
} 2>&1 | tee -a "$DEBUG_LOG"

