#!/bin/bash

. /home/nodo/common.sh

rm -rf /var/lib/tor/hidden_service
sleep 1
kill -HUP "$(pidof tor)"
sleep 1
tries=0
until test -f /var/lib/tor/hidden_service/hostname; do
	tries=$((tries + 1))
	if [ $tries -ge 10 ]; then
		exit 1
	fi
	sleep 1
done

putvar 'tor_address' "$(cat /var/lib/tor/hidden_service/hostname)"

rm -f /var/lib/i2pd/nasXmr.dat
rm -f /var/lib/i2pd/nasXmrRpc.dat
rm -f /var/lib/i2pd/nasXmrLws.dat
sleep 1
kill -HUP "$(pidof i2pd)"
sleep 1
tries=0
until test -f /var/lib/i2pd/nasXmr.dat; do
	tries=$((tries + 1))
	if [ $tries -ge 10 ]; then
		exit 1
	fi
	sleep 1
done

# TODO: these can all use the same variable.
putvar 'i2p_address' $(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmr.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")
putvar 'i2p_b32_addr_rpc' $(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmr.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")
putvar 'i2p_b32_addr_lws' $(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmr.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")

