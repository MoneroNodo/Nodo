#!/bin/bash

set -e

_cwd="$(pwd)"
test "$_cwd" = "" && exit 1

. "$_cwd"/home/nodo/common.sh

# remove duplicate entries in the default sysctl.conf file
# TODO eventually delete this
cp /etc/sysctl.conf /etc/sysctl.backup
cat /etc/sysctl.backup | head -n 67 > /etc/sysctl.conf

##Disable IPv6 (confuses Monero start script if IPv6 is present)
#and IPv6 sucks
showtext "Disabling IPv6..."
# write/overwrite conf file for this
cat << "EOF" >  /etc/sysctl.d/10-nodo.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
vm.nr_hugepages=3072
vm.swappiness=10
EOF

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

#Attempt update of tor hidden service settings
{
	if [ -f /usr/bin/tor ]; then #Crude way of detecting tor installed
		showtext "Updating tor hidden service settings..."
		cp "$_cwd"/etc/tor/torrc /etc/tor/torrc
		showtext "Applying Settings..."
		chmod 644 /etc/tor/torrc
		chown root /etc/tor/torrc
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
crontab "${_cwd}"/var/spool/cron/crontabs/root 2>&1 | tee -a "$DEBUG_LOG"

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
ufw --force enable

chmod o+rx /home/nodo
chmod o+rx /home/nodo/execScripts
chmod 666 /home/nodo/variables/config.json

hostname Nodo-N6
sed -i 's/NanoPC-T6N/Nodo-N6/g' /etc/hosts

if [ ! -d /opt/moneropay ]; then  # setup moneropay wallet dir
	adduser --system --group moneropay
	mkdir -p /opt/moneropay
	chown -R moneropay:moneropay /opt/moneropay
	chmod -R 600 /opt/moneropay
	systemctl enable --now monero-wallet-rpc
	systemctl enable --now moneropay
fi

systemctl disable --now bluetooth

userdel -fr pi

sudo -u nodo pipx uninstall libretranslate
sudo -u nodo rm -rf /home/nodo/.local/share/argos-translate


_tz="$(getvar 'timezone')"
if [ "$_tz" = "Europe/London" ]; then
	putvar 'timezone' 'GMT'
	systemctl restart nodoUI
fi

if [ "$_tz" = "Europe/Berlin" ]; then
	putvar 'timezone' 'CET'
	systemctl restart nodoUI
fi

putvar 'zmq_pub' '18083'
putvar 'tor_port' '18084'
putvar 'i2p_port' '18085'
putvar 'lws_port' '18086'
putvar 'monero_port' '18080'
putvar 'monero_public_port' '18081'
putvar 'monero_rpc_port' '18089'
kill -HUP "$(pidof tor)"
kill -HUP "$(pidof i2pd)"
