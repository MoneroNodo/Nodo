#!/bin/bash
# Just a root wrapper for the update scripts. Bit silly, I know

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

if [ ! "$EUID" = "0" ]; then
	exit 1
fi

if ! check_connection; then
	exit 1
fi

bash /home/nodo/update-nodo.sh
cd /home/nodo || exit 1
chown nodo:nodo -R nodoui monero monero-lws xmrig onion-monero-block-explorer
mkdir -p /home/nodo/bin
chown nodo:nodo /home/nodo/bin
success=0
sudo -u nodo bash /home/nodo/update-xmrig.sh && success=1
sudo -u nodo bash /home/nodo/update-pay.sh && success=1
sudo -u nodo bash /home/nodo/update-monero.sh && {
sudo -u nodo bash /home/nodo/update-monero-lws.sh
sudo -u nodo bash /home/nodo/update-explorer.sh
} && success=1
sudo bash /home/nodo/update-nodoui.sh && success=1

# Restart services afterwards,
# otherwise the device would be nothing more than a very warm brick
if [ 1 -eq $success ]; then
	services-stop
	sleep 1
	services-start
fi
