#!/bin/bash

set -e

_cwd="$(pwd)"
test "$_cwd" = "" && exit 1

. "$_cwd"/home/nodo/common.sh

##Disable IPv6 (confuses Monero start script if IPv6 is present)
#and IPv6 sucks
showtext "Disabling IPv6..."
echo 'net.ipv6.conf.all.disable_ipv6 = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.lo.disable_ipv6 = 1' | tee -a /etc/sysctl.conf
echo 'vm.nr_hugepages=3072' | tee -a /etc/sysctl.conf
echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf

##Perform system update and upgrade now. This then allows for reboot before next install step, preventing warnings about kernal upgrades when installing the new packages (dependencies).
#setup debug file to track errors
showtext "Creating Debug log..."
touch "$DEBUG_LOG"
chown nodo "$DEBUG_LOG"
chmod 777 "$DEBUG_LOG"

_APTGET='DEBIAN_FRONTEND=noninteractive apt -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages'

eval "$_APTGET" install apt-transport-https lsb-release curl

printf  'deb https://repo.i2pd.xyz/debian %s main' "$(lsb_release -sc)" \
	| tee /etc/apt/sources.list.d/i2pd.list
printf  'deb-src https://repo.i2pd.xyz/debian %s main' "$(lsb_release -sc)" \
	| tee -a /etc/apt/sources.list.d/i2pd.list
wget -q -O - https://repo.i2pd.xyz/r4sas.gpg | apt-key add -

apt update

eval "$_APTGET" install tor i2pd nodejs npm mariadb-client mariadb-server screen fail2ban ufw dialog jq libcurl4-openssl-dev libpthread-stubs0-dev cron exfat-fuse git chrony mingetty build-essential ccache cmake libboost-all-dev miniupnpc libunbound-dev graphviz doxygen libunwind8-dev pkg-config libssl-dev libcurl4-openssl-dev libgtest-dev libreadline-dev libzmq3-dev libsodium-dev libhidapi-dev libhidapi-libusb0 libuv1-dev libhwloc-dev apparmor apparmor-utils apparmor-profiles libcairo2-dev libxt-dev libgirepository1.0-dev gobject-introspection python3-yaml python3-pyyaml-env-tag gdisk xfsprogs build-essential cmake pkg-config libssl-dev libzmq3-dev libunbound-dev libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libldns-dev libexpat1-dev libpgm-dev libhidapi-dev libusb-1.0-0-dev libprotobuf-dev protobuf-compiler libudev-dev libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev libboost-locale-dev libboost-program-options-dev libboost-regex-dev libboost-all-dev libboost-serialization-dev libboost-system-dev libboost-thread-dev ccache doxygen graphviz pipx apache2 shellinabox php php-common libgtest-dev xxd 2>&1 | tee -a "$DEBUG_LOG"
eval "$_APTGET" -t bookworm-backports install golang-go tor

#force confnew by default everywhere
echo "force-confnew" >/etc/dpkg/dpkg.cfg.d/force-confnew

##Update and Upgrade system
showtext "Downloading and installing OS updates..."
{
	apt update
	eval "$_APTGET" dist-upgrade
	eval "$_APTGET" upgrade
	##Auto remove any obsolete packages
	eval "$_APTGET" apt autoremove
} 2>&1 | tee -a "$DEBUG_LOG"

##Installing dependencies for --- Web Interface
showtext "Installing dependencies for Web Interface..."
usermod -a -G nodo www-data

showtext "Install home contents"
cp -vr "$_cwd"/home/nodo/* /home/nodo/
cp -vr "$_cwd"/etc/* /etc/
cp "$_cwd"/update-*sh "$_cwd"/recovery.sh /home/nodo/
chown -v nodo:nodo /home/nodo/*

##Configure ssh security. Allows only user 'nodo'. Also 'root' login disabled via ssh, restarts config to make changes
showtext "Configuring SSH security..."
{
	# cp "${_cwd}"/etc/ssh/sshd_config /etc/ssh/sshd_config
	chmod 644 /etc/ssh/sshd_config
	chown root /etc/ssh/sshd_config
	systemctl restart sshd.service
} 2>&1 | tee -a "$DEBUG_LOG"
showtext "SSH security config complete"

##Copy MoneroNodo scripts to home folder
showtext "Moving MoneroNodo scripts into position..."
{
	cp -r "$_cwd"/home/nodo/* /home/nodo/
	cp -r "$_cwd"/home/nodo/.profile /home/nodo/
} 2>&1 | tee -a "$DEBUG_LOG"

showtext "Configuring apache server for access to Monero log file..."
{
	cp "$_cwd"/etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf
	chmod 777 /etc/apache2/sites-enabled/000-default.conf
	chown root /etc/apache2/sites-enabled/000-default.conf
	test ! -f /etc/ssl/private/moneronodo.key && openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/moneronodo.key -out /etc/ssl/certs/moneronodo.crt -sha256 -days 3650 -nodes -subj "/C=US/ST=StateName/L=CityName/O=Nodo/OU=CompanySectionName/CN=moneronodo.local" -addext "subjectAltName=DNS:moneronodo.lan,DNS:moneronodo"
	systemctl restart apache2
} 2>&1 | tee -a "$DEBUG_LOG"

##Install log.io (Real-time service monitoring)
#Establish Device IP
DEVICE_IP=$(getip)
showtext "Installing log.io..."

{
	npm install -g log.io
	npm install -g log.io-file-input
	mkdir -p ~/.log.io/inputs/
	cp "$_cwd"/.log.io/inputs/file.json ~/.log.io/inputs/file.json
	cp "$_cwd"/.log.io/server.json ~/.log.io/server.json
	sed -i "s/127.0.0.1/$DEVICE_IP/g" ~/.log.io/server.json
	sed -i "s/127.0.0.1/$DEVICE_IP/g" ~/.log.io/inputs/file.json
	systemctl start log-io-server.service
	systemctl start log-io-file.service
	systemctl enable log-io-server.service
	systemctl enable log-io-file.service
} 2>&1 | tee -a "$DEBUG_LOG"

#Install webui
showtext "Installing python dependencies..."
{
	cd /home/nodo/webui || return 1
	apt install -y software-properties-common
	apt install -y python3.11 python3.11-dev python3-pip python3.11-venv
	showtext "Creating virtualenv, may take a minute..."
	python3.11 -m venv venv
	(
		. venv/bin/activate
		venv/bin/pip install --upgrade pip
		venv/bin/pip install Cython
		venv/bin/pip install numpy
		venv/bin/pip install dash
		venv/bin/pip install dash_bootstrap_components dash_mantine_components dash_iconify
		venv/bin/pip install Pyarrow
		venv/bin/pip install pandas
		venv/bin/pip install dasbus
		venv/bin/pip install dash_breakpoints dash_daq
		venv/bin/pip install furl
		venv/bin/pip install psutil
		venv/bin/pip install dash-qr-manager
		venv/bin/pip install pycairo
		venv/bin/pip install PyGObject
		venv/bin/python -m compileall .
	)
	chown nodo:nodo -R /home/nodo/webui
	chmod gu+rx /home/nodo/webui
} 2>&1 | tee -a "$DEBUG_LOG"

showtext "Installing LibreTranslate"
{
	sudo -u nodo pipx install libretranslate
	systemctl enable --now libretranslate
} 2>&1 | tee -a "$DEBUG_LOG"

#Attempt update of tor hidden service settings
{
	if [ -f /usr/bin/tor ]; then #Crude way of detecting tor installed
		showtext "Updating tor hidden service settings..."
		cp "$_cwd"/etc/tor/torrc /etc/tor/torrc
		showtext "Applying Settings..."
		chmod 644 /etc/tor/torrc
		chown root /etc/tor/torrc
		#Insert user specific local IP for correct hiddenservice redirect (line 73 overwrite)
		sed -i "73s/.*/HiddenServicePort 18081 $(hostname -I | awk '{print $1}'):18081/" /etc/tor/torrc
		showtext "Restarting tor service..."
		service tor restart
	fi
} 2>&1 | tee -a "$DEBUG_LOG"

putvar 'tor_address' "$(cat /var/lib/tor/hidden_service/hostname)"

##Set Swappiness lower
showtext "Decreasing swappiness..."
sysctl vm.swappiness=10 2> >(tee -a "$DEBUG_LOG" >&2)

##Install crontab
showtext "Setting up crontab..."
cp -vr "${_cwd}"/var/spool/cron/crontabs/root /var/spool/cron/crontabs/root 2>&1 | tee -a "$DEBUG_LOG"

showtext "Resetting and setting up UFW..."
ufw --force reset
ufw disable
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow 18080:18090/tcp
ufw allow 18080:18090/udp
ufw allow 4200
ufw allow 4444 # i2p http
ufw allow 4447 # i2p socks
ufw allow 8133  #lws
ufw --force enable

chmod o+rx /home/nodo
chmod o+rx /home/nodo/execScripts
chmod 666 /home/nodo/variables/config.json

sleep 5
kill -HUP "$(pidof i2pd)"
kill -HUP "$(pidof tor)"
sleep 5
putvar 'i2p_address' $(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmr.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")
putvar 'i2p_b32_addr_rpc' $(printf "%s.b32.i2p" "$(head -c 391 /var/lib/i2pd/nasXmrRpc.dat | sha256sum | xxd -r -p | base32 | sed s/=//g | tr A-Z a-z)")
putvar 'tor_address' "$(cat /var/lib/tor/hidden_service/hostname)"

