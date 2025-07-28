#!/bin/bash

. "$_cwd"/home/nodo/common.sh

cd /media/monero/ || exit 1

# Cleanup
[[ -f mrl_banlist ]] && rm mrl_banlist
[[ -f xmrpm_banlist ]] && rm xmrpm_banlist

# Pull list(s) & set failures
mrl_banlist=""
xmrpm_banlist=""
if [[ "$(getvar "banlists.boog900")" == "TRUE" ]]; then
	curl -LSs https://github.com/Boog900/monero-ban-list/raw/refs/heads/main/ban_list.txt -o mrl_banlist || xmrpm_banlist="xmr.pm banlist"
fi
if [[ "$(getvar 'banlists."gui-xmr-pm"')" == "TRUE" ]] then
	curl -LSs https://gui.xmr.pm/files/block.txt -o xmrpm_banlist || mrl_banlist="mrl banlist"
fi

# Combine results
{
	[[ -f xmrpm_banlist ]] && cat xmrpm_banlist
	[[ -f mrl_banlist ]] && cat mrl_banlist
} | sort -u > newbanlist

# Generate banlist.txt
if [[ -n "${mrl_banlist}" ]] || [[ -n "${xmrpm_banlist}" ]]; then
	echo "Failed to update one or more of the banlists"
	if [[ $(cat banlist.txt) != "" ]]; then
		echo "Using old banlist.txt"
		exit 0
	elif [[ $(cat newbanlist) != "" ]]; then
		echo "Using the ${xmrpm_banlist}${mrl_banlist}"
	else
		echo "Creating blank placeholder banlist.txt"
	fi
elif [[ $(cat newbanlist) == $(cat banlist.txt) ]]; then
	echo "Banlist up-to-date"
	exit 0
else
	echo "Generating new banlist.txt"
fi

# Copy files
cp newbanlist banlist.txt
chown monero:monero banlist.txt
chmod 600 banlist.txt
