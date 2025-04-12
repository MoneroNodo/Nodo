#!/bin/bash

. "$_cwd"/home/nodo/common.sh

cd /media/monero/ || exit 1

mrl_banlist=""
xmrpm_banlist=""
{
	[ "$(getvar "banlists.boog900")" == "TRUE" ] && curl -LSs https://github.com/Boog900/monero-ban-list/raw/refs/heads/main/ban_list.txt || echo "MRL list failed to update"; mrl_banlist="mrl banlist"
	[ "$(getvar 'banlists."gui-xmr-pm"')" == "TRUE" ] && curl -LSs https://gui.xmr.pm/files/block.txt || echo "xmr.pm banlist failed to update"; xmrpm_banlist="xmr.pm banlist"
} | sort -u > newbanlist

if [[ -z "${mrl_banlist}" ]] && [[ -z "${xmrpm_banlist}" ]]; then
	if [[ $(cat newbanlist) == $(cat banlist.txt) ]]; then
		echo "Banlist up-to-date"
		exit 0
	else
		echo "Generating new banlist.txt"
	fi
else
	if [[ -f banlist.txt ]]; then
		if [[ $(cat banlist.txt) != "" ]]; then
			echo "Using old banlist.txt instead"
			exit 1
		fi
	elif [[ $(cat newbanlist) != "" ]]; then
		echo "Using the ${xmrpm_banlist}${mrl_banlist}"
	else
		echo "Creating blank placeholder banlist.txt"
	fi
fi
cp newbanlist banlist.txt
chown monero:monero banlist.txt
chmod 600 banlist.txt
