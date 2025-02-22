#!/bin/bash

##Open Sources:
# Monero github https://github.com/moneroexamples/monero-compilation/blob/master/README.md
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

bash "$_cwd"/home/nodo/setup-drive.sh "${_cwd}"

showtext "Setting up Monero..."
# Install monero for the first time
(
	cd || exit
	git clone https://github.com/MoneroNodo/mesa
	cd mesa || exit
	sudo bash ./install_mesa.sh

	mkdir -p /home/nodo/bin
	chown nodo:nodo /home/nodo/bin
	chmod a+rx /home/nodo/bin
	cd /home/nodo || exit 1

	export FIRSTINSTALL=1

	showtext "Setting up Monero Daemon"
	sudo -u nodo bash /home/nodo/update-monero.sh 1

	showtext "Setting up Monero LWS"
	sudo -u nodo bash /home/nodo/update-monero-lws.sh 1

	showtext "Setting up NodoUI"
	bash /home/nodo/update-nodoui.sh 1

	showtext "Setting up MoneroPay"
	sudo -u nodo bash /home/nodo/update-pay.sh 1

)
showtext "Start services"

systemctl daemon-reload
systemctl enable --now tor i2pd apparmor
systemctl enable --now monerod monero-lws
systemctl enable --now monero-wallet-rpc

services-start
sleep 3
swapfile=/media/monero/swap
sleep 1
showtext "Setting up swap on $swapfile"
dd if=/dev/zero of="$swapfile" bs=1G count=10 conv=sync
mkswap "$swapfile"
printf '%s none swap defaults 0 0' "$swapfile" | tee -a /etc/fstab
swapon "$swapfile"

sleep 5
bash /home/nodo/setup-domains.sh

## Install complete
showtext "Installation Complete"
