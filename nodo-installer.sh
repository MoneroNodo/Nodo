#!/bin/bash

##Open Sources:
# Web-UI by designmodo Flat-UI free project at https://github.com/designmodo/Flat-UI
# Monero github https://github.com/moneroexamples/monero-compilation/blob/master/README.md
# Monero Blockchain Explorer https://github.com/moneroexamples/onion-monero-blockchain-explorer
# MoneroNodo scripts and custom files at my repo https://github.com/shermand100/pinode-xmr
# PiVPN - OpenVPN server setup https://github.com/pivpn/pivpn

if [ ! "$EUID" = 0 ]; then
	printf '!! %s' "Please run as root"
	exit 1
fi

_cwd="$(pwd)"

#shellcheck source=home/nodo/common.sh
. "$_cwd"/home/nodo/common.sh
if check_connection; then
	showtext "Internet working fine -- starting installer"
else
	showtext "NO CONNECTION -- aborting!"
	exit 1
fi
systemctl disable --now gdm.service # no gnome-shell necessary

##Create new user 'nodo'
showtext "Creating user 'nodo'..."
adduser --gecos "" --disabled-password --home /home/nodo nodo
chmod a+rx /home/nodo
usermod -a -G sudo nodo
adduser --system --no-create-home --shell /bin/false --group monero

#Set nodo password 'MoneroNodo'
echo "nodo:MoneroNodo" | chpasswd
echo "root:$(openssl rand -base64 48)" | chpasswd
showtext "nodo password changed to 'MoneroNodo'"

##Change system hostname to MoneroNodo
showtext "Changing system hostname to 'MoneroNodo'..."
echo 'MoneroNodo' | tee /etc/hostname
#sed -i '6d' /etc/hosts
echo '127.0.0.1       MoneroNodo' | tee -a /etc/hosts
hostname MoneroNodo

###Clone MoneroNodo to device from git
#showtext "Downloading MoneroNodo files..."
#git clone --single-branch https://github.com/MoneroNodo/Nodo.git 2>&1 | tee -a "$DEBUG_LOG"

showtext "setup-nodo.sh..."
bash "$_cwd"/setup-nodo.sh

bash "$_cwd"/home/nodo/setup-drive.sh

showtext "Setting up Monero..."
# Install monero for the first time
(
	cd /home/nodo || exit 1

	export FIRSTINSTALL=1
	mkdir -p /home/nodo/bin
	chown nodo:nodo /home/nodo/bin
	chmod a+rx /home/nodo/bin

	showtext "Setting up Monero Daemon"
	sudo -u nodo bash ./update-monero.sh

	showtext "Setting up Block Explorer"
	sudo -u nodo bash ./update-explorer.sh

	showtext "Setting up Monero LWS"
	sudo -u nodo bash ./update-monero-lws.sh

	showtext "Setting up P2Pool"
	sudo -u nodo bash ./update-p2pool.sh

	showtext "Setting up XMRig"
	sudo -u nodo bash ./update-xmrig.sh

	showtext "Setting up Nodo UI"
	sudo -u nodo bash ./update-nodoui.sh
)
showtext "Start services"

systemctl daemon-reload
systemctl enable --now tor i2pd apparmor
systemctl enable --now monerod block-explorer monero-lws monero-lws-admin webui p2pool

services-start
sleep 3
swapfile=/media/monero/swap
sleep 1
showtext "Setting up swap on $swapfile"
dd if=/dev/zero of="$swapfile" bs=1M count=1024 conv=sync
mkswap "$swapfile"
printf '%s none swap defaults 0 0' "$swapfile" | tee -a /etc/fstab
swapon "$swapfile"

putvar 'i2p_b32_addr' $(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmr.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")
putvar 'i2p_b32_addr_rpc' $(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmrRpc.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")
putvar 'onion_addr' "$(cat /var/lib/tor/hidden_service/hostname)"

## Install complete
showtext "Installation Complete"
