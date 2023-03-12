#!/bin/bash

echo "
####################
" 2>&1 | tee -a /home/nanode/debug.log
echo "Start setup-update-p2pool.sh script $(date)" 2>&1 | tee -a /home/nanode/debug.log
echo "
####################
" 2>&1 | tee -a /home/nanode/debug.log


#Stop Node to make system resources available.
sudo systemctl stop blockExplorer.service
sudo systemctl stop moneroPrivate.service
sudo systemctl stop moneroMiningNode.service
sudo systemctl stop moneroTorPrivate.service
sudo systemctl stop moneroTorPublic.service
sudo systemctl stop moneroPublicFree.service
sudo systemctl stop moneroI2PPrivate.service
sudo systemctl stop moneroCustomNode.service
sudo systemctl stop moneroPublicRPCPay.service
sudo systemctl stop p2pool.service
echo "Monero node stop command sent to make system resources available for update, allowing 30 seconds for safe shutdown"
sleep "10"
echo "Update starts in 20 seconds"
sleep "10"
echo "Update starts in 10 seconds"
sleep "5"
echo "Update starts in 5 seconds"
sleep "5"
echo -e "\e[32mDelete old version\e[0m"
rm -rf /home/nanode/p2pool/
echo -e "\e[32mSuccess\e[0m"
sleep "2"
echo -e "\e[32mBuilding new P2Pool\e[0m"
##Install P2Pool
git clone --recursive https://github.com/SChernykh/p2pool 2>&1 | tee -a /home/nanode/debug.log
cd p2pool
git checkout tags/v3.0
mkdir build && cd build
cmake .. 2>&1 | tee -a /home/nanode/debug.log
make -j2 2>&1 | tee -a /home/nanode/debug.log
echo -e "\e[32mSuccess\e[0m"
sleep 3
cd
#Update system reference Explorer version number version number
chmod 755 /home/nanode/p2pool-new-ver.sh
. /home/nanode/p2pool-new-ver.sh
echo "#!/bin/bash
CURRENT_VERSION_P2POOL=$NEW_VERSION_P2POOL" > /home/nanode/current-ver-p2pool.sh 2>&1 | tee -a /home/nanode/debug.log

#Define Restart Monero Node
# Key - BOOT_STATUS
# 2 = idle
# 3 || 5 = private node || mining node
# 4 = tor
# 6 = Public RPC pay
# 7 = Public free
# 8 = I2P
# 9 tor public
if [[ $BOOT_STATUS -eq 2 ]]
then
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Node ready for start. See web-ui at $(hostname -I) to select mode." 16 60
fi

if [[ $BOOT_STATUS -eq 3 ]]
then
	sudo systemctl start moneroPrivate.service
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Your Monero Node has resumed." 16 60
fi

if [[ $BOOT_STATUS -eq 4 ]]
then
	sudo systemctl start moneroTorPrivate.service
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Your Monero Node has resumed." 16 60
fi

if [[ $BOOT_STATUS -eq 5 ]]
then
	sudo systemctl start moneroMiningNode.service
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Your Monero Node has resumed." 16 60
fi

if [[ $BOOT_STATUS -eq 6 ]]
then
	sudo systemctl start moneroPublicRPCPay.service
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Your Monero Node has resumed." 16 60
fi

if [[ $BOOT_STATUS -eq 7 ]]
then
	sudo systemctl start moneroPublicFree.service
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Your Monero Node has resumed." 16 60
fi

if [[ $BOOT_STATUS -eq 8 ]]
then
	sudo systemctl start moneroI2PPrivate.service
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Your Monero Node has resumed." 16 60
fi

if [[ $BOOT_STATUS -eq 9 ]]
then
	sudo systemctl start moneroTorPublic.service
	whiptail --title "P2Pool Update Complete" --msgbox "Update complete, Your Monero Node has resumed." 16 60
fi

	##End debug log
	echo "Update Script Complete" 2>&1 | tee -a /home/nanode/debug.log
	sleep 5
	echo "####################" 2>&1 | tee -a /home/nanode/debug.log
	echo "End setup-update-p2pool.sh script $(date)" 2>&1 | tee -a /home/nanode/debug.log
	echo "####################" 2>&1 | tee -a /home/nanode/debug.log
