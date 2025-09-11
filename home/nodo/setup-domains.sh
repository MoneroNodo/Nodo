#!/bin/bash

# -tor: setup tor domains
# -i2p: setup i2p domains
# no args: setup both tor and i2p domains

#shellcheck source=home/nodo/common.sh
. /root/nodo/home/nodo/common.sh || exit 1

if [ $# -eq 0 ]; then
	__tor=1
	__i2p=1
else
	while :; do
		case "$1" in
		'-tor')
			__tor=1
			;;
		'-i2p')
			__i2p=1
			;;
		*)
			break
			;;
		esac
		shift
	done
fi

if [ "$__tor" = "1" ]; then
	rm -rf /var/lib/tor/hidden_service
	rm -rf /var/lib/tor/ssh
	kill -HUP "$(pidof tor)"
	sleep 1
	kill -HUP "$(pidof tor)"
	sleep 1
	kill -HUP "$(pidof tor)"
	tries=0
	until test -f /var/lib/tor/hidden_service/hostname; do
		tries=$((tries + 1))
		if [ "$tries" -ge 20 ]; then
			exit 1
		fi
		sleep 1
	done

	test -f /var/lib/tor/hidden_service/hostname && putvar 'tor_address' "$(cat /var/lib/tor/hidden_service/hostname)"
	test -f /var/lib/tor/ssh/hostname && putvar 'tor_ssh_address' "$(cat /var/lib/tor/ssh/hostname)"
fi

if [ "$__i2p" = "1" ]; then
	rm -f /var/lib/i2pd/nasXmr.dat
	rm -f /var/lib/i2pd/nasXmrRpc.dat
	rm -f /var/lib/i2pd/nasXmrLws.dat
	kill -HUP "$(pidof i2pd)"
	sleep 1
	kill -HUP "$(pidof i2pd)"
	sleep 1
	kill -HUP "$(pidof i2pd)"
	tries=0
	until test -f /var/lib/i2pd/nasXmr.dat; do
		tries=$((tries + 1))
		if [ "$tries" -ge 20 ]; then
			exit 1
		fi
		sleep 1
	done

	test -f /var/lib/i2pd/nasXmr.dat && putvar 'i2p_address' "$(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmr.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")"
	test -f /var/lib/i2pd/nodoSSH.dat && putvar 'i2p_ssh_address' "$(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nodoSSH.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")"
fi
