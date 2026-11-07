#!/bin/bash

UPD="$(jq -r '.config.autoupdate.debian' /home/nodo/variables/config.json)"

if [ "$UPD" = "FALSE" ] && [ "$1" = "" ]; then
	echo "INFO : automatic debian updates disabled"
	exit 0
fi

. "$_cwd"/home/nodo/common.sh

tries=15
until check_connection; do
	if [ "$tries" -lt 1 ]; then
		echo "No internet?"
		return
	fi
	sleep 1
	tries=$((tries - 1))
done

{
	pkg_upgrade || true
} 2>&1 | tee -a "$DEBUG_LOG"
