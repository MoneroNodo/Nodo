#!/bin/bash
# Just a root wrapper for the update scripts. Bit silly, I know

#shellcheck source=home/nodo/common.sh
. /root/nodo/home/nodo/common.sh || exit 1

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

bash /root/nodo/update-nodo.sh
cd /home/nodo || exit 1
chown nodo:nodo -R nodoui monero monero-lws
mkdir -p /home/nodo/bin
chown nodo:nodo /home/nodo/bin
sudo --preserve-env=ALL_PROXY -u nodo bash /root/nodo/update-pay.sh
sudo --preserve-env=ALL_PROXY -u nodo bash /root/nodo/update-monero.sh && \
sudo --preserve-env=ALL_PROXY -u nodo bash /root/nodo/update-monero-lws.sh # LWS depends on Monero codebas
bash /root/nodo/update-nodoui.sh

# Ensure i2p and tor are properly configured.
expectedi2p=$(getvar 'i2p_address')
expectedtor=$(getvar 'tor_address')
i2phostname=$(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmr.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")
torhostname=$(cat /var/lib/tor/hidden_service/hostname)
generatetor() {
        bash /home/nodo/setup-domains.sh -tor
}
generatei2p() {
        bash /home/nodo/setup-domains.sh -i2p
}
if [ "" = "${expectedtor}" ]; then
	echo -e "Onion address is not set.\nGenerating onion hostname..."
	generatetor
elif [ "${torhostname}" != "${expectedtor}" ]; then
	echo -e "${expectedtor}\ndoes NOT match\n${torhostname}\nRegenerating..."
	generatetor
fi
if [ "" = "${expectedi2p}" ]; then
	echo -e "i2p address is not set.\nGenerating i2p hostname..."
	generatei2p
elif [ "${i2phostname}" != "${expectedi2p}" ]; then
	echo -e "${expectedi2p}\ndoes NOT match\n${i2phostname}\nRegenerating..."
	generatei2p
fi

remlockfile
