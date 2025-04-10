#!/bin/bash
# Just a root wrapper for the update scripts. Bit silly, I know

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

_lockfile=/home/nodo/variables/updatelock

remlockfile() {
	rm -f "$_lockfile"
}

if [ "$(jq '.config.versions | has("names")' < /home/nodo/variables/config.json)" = "false" ]; then
	putvar 'versions.names.nodo' "$(get_tag_name_from_commit "moneronodo" "nodo" "$(getvar "versions.nodo")")"
	# putvar 'versions.names.lws' "$(get_tag_name_from_commit "moneronodo" "nodo" "$(getvar "versions.nodo")")"
	putvar 'versions.names.pay' "$(get_tag_name_from_commit "moneropay" "moneropay" "$(getvar "versions.pay")")"
	putvar 'versions.names.monero' "$(get_tag_name_from_commit "monero-project" "monero" "$(getvar "versions.monero")")"
	putvar 'versions.names.nodoui' "$(get_tag_name_from_commit "moneronodo" "nodoui" "$(getvar "versions.nodoui")")"
fi

if [ ! "$EUID" = "0" ]; then
	printf '%s\n' "Not root, can't update"
	exit 1
fi

if [ ! -f "/home/nodo/variables/firstboot" ]; then
	printf '%s\n' "First boot process ongoing, can't update yet"
	exit 1
fi

if [ -f "$_lockfile" ]; then
	printf '%s\n' "Updater lockfile present, can't update yet"
	exit 1
fi

if ! check_connection; then
	printf '%s\n' "No network connection, can't update"
	exit 1
fi

timediff="${1:-3600}"
if [ "$(getvar last_update)" = "null" ] || [ "$timediff" -le "1" ] || [ "$(getvar last_update)" -le "$(($(date +%s) - timediff))" ]; then
	putvar last_update "$(date +%s)"
	printf '%s\n' "Checking for updates"
else
	printf '%s. %s vs %s\n' "Last update check too recent, can't update yet" "$(date -d @"$(getvar last_update)")" "$(date)"
	exit 1
fi

trap remlockfile INT HUP EXIT

touch "$_lockfile"

ALL_PROXY=
if [ "$(getvar tor_global_enabled)" = "TRUE" ]; then
	ALL_PROXY=socks5h://127.0.0.1:9050
fi
export ALL_PROXY

bash /home/nodo/update-nodo.sh
cd /home/nodo || exit 1
chown nodo:nodo -R nodoui monero monero-lws
mkdir -p /home/nodo/bin
chown nodo:nodo /home/nodo/bin
success=0
sudo --preserve-env=ALL_PROXY -u nodo bash /home/nodo/update-pay.sh && success=1
sudo --preserve-env=ALL_PROXY -u nodo bash /home/nodo/update-monero.sh && \
sudo --preserve-env=ALL_PROXY -u nodo bash /home/nodo/update-monero-lws.sh && success=1 # LWS depends on Monero codebase
bash /home/nodo/update-nodoui.sh && success=1

# Restart services afterwards,
# otherwise the device would be nothing more than a very warm brick
if [ 1 -eq $success ]; then
	services-stop
	sleep 1
	services-start
fi

if [ "" = "$(getvar 'tor_address')" ] || [ "" = "$(getvar 'i2p_address')" ]; then
	bash /home/nodo/setup-domains.sh
fi

remlockfile
