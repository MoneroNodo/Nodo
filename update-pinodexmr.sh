#!/bin/bash

if (whiptail --title "PiNode-XMR Updater" --yesno "This will update PiNode-XMR to the newest version\n\nContinue?" 12 78); then

sudo apt update && sudo apt upgrade -y
sleep 3

##Checking all dependencies are installed for --- Web Interface
echo -e "\e[32m##Checking all dependencies are installed for --- Web Interface\e[0m"
sleep 3
sudo apt install apache2 shellinabox php7.3 php7.3-cli php7.3-common php7.3-curl php7.3-gd php7.3-json php7.3-mbstring php7.3-mysql php7.3-xml -y
echo -e "\e[32mSuccess\e[0m"
sleep 3

##Checking all dependencies are installed for --- Monero
echo -e "\e[32m##Checking all dependencies are installed for --- Monero\e[0m"
sleep 3
sudo apt install git build-essential cmake libpython2.7-dev libboost-all-dev miniupnpc pkg-config libunbound-dev graphviz doxygen libunwind8-dev libssl-dev libcurl4-openssl-dev libgtest-dev libreadline-dev libzmq3-dev libsodium-dev libhidapi-dev libhidapi-libusb0 -y
echo -e "\e[32mSuccess\e[0m"
sleep 3

##Checking all dependencies are installed for --- miscellaneous (security tools-fail2ban-ufw, menu tool-dialog, screen, mariadb)
echo -e "\e[32mChecking all dependencies are installed for --- Miscellaneous\e[0m"
sleep 3
sudo apt install mariadb-client-10.0 mariadb-server-10.0 screen exfat-fuse exfat-utils fail2ban ufw dialog python3-pip jq -y
	## Installing new dependencies for IP2Geo map creation
sudo apt install python3-numpy libgeos-dev python3-geoip2 libatlas-base-dev python3-mpltoolkits.basemap -y
	##More IP2Geo dependencies - matplotlibv3.2.1 required for basemap support - post v3.3 basemap depreciated
sudo pip3 install ip2geotools matplotlib==3.2.1

		#Download update files

					wget https://raw.githubusercontent.com/monero-ecosystem/PiNode-XMR/Armbian-install/new-ver-pi.sh -O /home/pinodexmr/new-ver-pi.sh
					chmod 755 /home/pinodexmr/new-ver-pi.sh
					. /home/pinodexmr/new-ver-pi.sh
					echo "Latest Version: $NEW_VERSION_PI "
					echo -e "\e[32mDownloading PiNode-XMR files\e[0m"
					sleep 2
					
					git clone -b Raspbian-install --single-branch https://github.com/monero-ecosystem/PiNode-XMR.git
					wget https://raw.githubusercontent.com/monero-ecosystem/PiNode-XMR/Armbian-install/new-ver-pi.sh -O /home/pinodexmr/new-ver-pi.sh

					#Backup User values
					echo -e "\e[32mCreating backups of your configuration\e[0m"
					sleep 2
					mv /home/pinodexmr/bootstatus.sh /home/pinodexmr/bootstatus_retain.sh
					mv /home/pinodexmr/credits.sh /home/pinodexmr/credits_retain.sh
					mv /home/pinodexmr/current-ver.sh /home/pinodexmr/current-ver_retain.sh
					mv /home/pinodexmr/current-ver-exp.sh /home/pinodexmr/current-ver-exp_retain.sh
					mv /home/pinodexmr/current-ver-pi.sh /home/pinodexmr/current-ver-pi_retain.sh
					mv /home/pinodexmr/difficulty.sh /home/pinodexmr/difficulty_retain.sh
					mv /home/pinodexmr/error.log /home/pinodexmr/error_retain.log
					mv /home/pinodexmr/explorer-flag.sh /home/pinodexmr/explorer-flag_retain.sh
					mv /home/pinodexmr/in-peers.sh /home/pinodexmr/in-peers_retain.sh
					mv /home/pinodexmr/limit-rate-down.sh /home/pinodexmr/limit-rate-down_retain.sh
					mv /home/pinodexmr/limit-rate-up.sh /home/pinodexmr/limit-rate-up_retain.sh
					mv /home/pinodexmr/mining-address.sh /home/pinodexmr/mining-address_retain.sh
					mv /home/pinodexmr/mining-intensity.sh /home/pinodexmr/mining-intensity_retain.sh
					mv /home/pinodexmr/monero-port.sh /home/pinodexmr/monero-port_retain.sh
					mv /home/pinodexmr/monero-stats-port.sh /home/pinodexmr/monero-stats-port_retain.sh
					mv /home/pinodexmr/out-peers.sh /home/pinodexmr/out-peers_retain.sh
					mv /home/pinodexmr/payment-address.sh /home/pinodexmr/payment-address_retain.sh
					mv /home/pinodexmr/prunestatus.sh /home/pinodexmr/prunestatus_status.sh
					mv /home/pinodexmr/RPCp.sh /home/pinodexmr/RPCp_retain.sh
					mv /home/pinodexmr/RPCu.sh /home/pinodexmr/RPCu_retain.sh
					
						#Install Update
					echo -e "\e[32mInstalling update\e[0m"
					sleep 2
						##Update PiNode-XMR systemd services
					echo -e "\e[32mUpdating PiNode-XMR systemd services\e[0m"
					sleep 2
					sudo mv /home/pinodexmr/pinode-xmr/etc/systemd/system/*.service /etc/systemd/system/
					sudo chmod 644 /etc/systemd/system/*.service
					sudo chown root /etc/systemd/system/*.service
					echo -e "\e[32mSuccess\e[0m"
					sleep 2
						##Updating PiNode-XMR scripts in home directory
					echo -e "\e[32mUpdating PiNode-XMR scripts in home directory\e[0m"
					sleep 2
					sudo rm -R /home/pinodexmr/flock #if folder not removed produces error, cannot be overwritten if not empty
					mv /home/pinodexmr/pinode-xmr/home/pinodexmr/* /home/pinodexmr/
					mv /home/pinodexmr/pinode-xmr/home/pinodexmr/.profile /home/pinodexmr/
					chmod 777 /home/pinodexmr/*
					echo -e "\e[32mSuccess\e[0m"
					sleep 2
						##Update web interface
					echo -e "\e[32mUpdating your Web Interface\e[0m"
					sleep 2
					sudo mv /home/pinodexmr/pinode-xmr/HTML/*.* /var/www/html/
					sudo cp -R /home/pinodexmr/pinode-xmr/HTML/docs/ /var/www/html/
					sudo chown www-data -R /var/www/html/
					sudo chmod 777 -R /var/www/html/
					echo -e "\e[32mSuccess\e[0m"
										
					#Restore User Values
					echo -e "\e[32mRestoring your configuration\e[0m"
					sleep 2
					mv /home/pinodexmr/bootstatus_retain.sh /home/pinodexmr/bootstatus.sh
					mv /home/pinodexmr/credits_retain.sh /home/pinodexmr/credits.sh
					mv /home/pinodexmr/current-ver_retain.sh /home/pinodexmr/current-ver.sh
					mv /home/pinodexmr/current-ver-exp_retain.sh /home/pinodexmr/current-ver-exp.sh
					mv /home/pinodexmr/current-ver-pi_retain.sh /home/pinodexmr/current-ver-pi.sh
					mv /home/pinodexmr/difficulty_retain.sh /home/pinodexmr/difficulty.sh
					mv /home/pinodexmr/error_retain.log /home/pinodexmr/error.log
					mv /home/pinodexmr/explorer-flag_retain.sh /home/pinodexmr/explorer-flag.sh
					mv /home/pinodexmr/in-peers_retain.sh /home/pinodexmr/in-peers.sh
					mv /home/pinodexmr/limit-rate-down_retain.sh /home/pinodexmr/limit-rate-down.sh
					mv /home/pinodexmr/limit-rate-up_retain.sh /home/pinodexmr/limit-rate-up.sh
					mv /home/pinodexmr/mining-address_retain.sh /home/pinodexmr/mining-address.sh
					mv /home/pinodexmr/mining-intensity_retain.sh /home/pinodexmr/mining-intensity.sh
					mv /home/pinodexmr/monero-port_retain.sh /home/pinodexmr/monero-port.sh
					mv /home/pinodexmr/monero-stats-port_retain.sh /home/pinodexmr/monero-stats-port.sh
					mv /home/pinodexmr/out-peers_retain.sh /home/pinodexmr/out-peers.sh
					mv /home/pinodexmr/payment-address_retain.sh /home/pinodexmr/payment-address.sh
					mv /home/pinodexmr/prunestatus_status.sh /home/pinodexmr/prunestatus.sh
					mv /home/pinodexmr/RPCp_retain.sh /home/pinodexmr/RPCp.sh
					mv /home/pinodexmr/RPCu_retain.sh /home/pinodexmr/RPCu.sh
					echo -e "\e[32mSuccess\e[0m"
					
				##Add Selta's ban list
					echo -e "\e[32mAdding Selstas Ban List\e[0m"
					sleep 3
					wget -O block.txt https://gui.xmr.pm/files/block.txt
					echo -e "\e[32mSuccess\e[0m"
					sleep 3

				##Set Swappiness lower
				echo -e "\e[32mDecreasing swappiness\e[0m"
				sleep 3				
				sudo sysctl vm.swappiness=10
				echo -e "\e[32mSuccess\e[0m"
				sleep 3						

					##Update crontab
					echo -e "\e[32mSetup crontab\e[0m"
					sleep 3
					sudo crontab /home/pinodexmr/pinode-xmr/var/spool/cron/crontabs/root
					crontab /home/pinodexmr/pinode-xmr/var/spool/cron/crontabs/pinodexmr
					echo -e "\e[32mSuccess\e[0m"
					sleep 3

					#Update system version number to new one installed
					echo -e "\e[32mUpdate system version number\e[0m"
					echo "#!/bin/bash
CURRENT_VERSION_PI=$NEW_VERSION_PI" > /home/pinodexmr/current-ver-pi.sh
					echo -e "\e[32mSuccess\e[0m"
					sleep 2
					
					#Clean up files
					echo -e "\e[32mCleanup leftover directories\e[0m"
					sleep 2
					sudo rm -r /home/pinodexmr/pinode-xmr/
					rm /home/pinodexmr/new-ver-pi.sh
					echo -e "\e[32mSuccess\e[0m"
					sleep 2
					
					whiptail --title "PiNode-XMR Updater" --msgbox "\n\nYour PiNode-XMR has been updated to version ${NEW_VERSION_PI}" 12 78
					
		sleep 5
else
    . /home/pinodexmr/setup.sh
fi

#Return to menu
./setup.sh
