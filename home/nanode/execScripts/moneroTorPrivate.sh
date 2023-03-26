#!/bin/bash

#shellcheck source=home/nanode/common.sh
. /home/nanode/common.sh
#Extra display hidden service address incase of error on tor install
sudo cat /var/lib/tor/hidden_service/hostname | tee /var/www/html/onion-address.txt
#Onion Public Address
NAME_FILE="/var/lib/tor/hidden_service/hostname"
ONION_ADDR="$(sudo cat $NAME_FILE)"
ANONYMOUS_INBOUND="${ONION_ADDR},127.0.0.1:18083"
#Import Start Flag Values:
DEVICE_IP=$(getip)
IN_PEERS=$(getvar "in_peers")
OUT_PEERS=$(getvar "out_peers")
LIMIT_RATE_UP=$(getvar "limit_rate_up")
LIMIT_RATE_DOWN=$(getvar "limit_rate_down")
RPCu=$(getvar "rpcu")
RPCp=$(getvar "rpcp")
DATA_DIR=$(getvar "data_dir")
SYNC_MODE=$(getvar "sync_mode")

putvar "boot_status" "4"
#Start Monerod
DNS_PUBLIC=tcp TORSOCKS_ALLOW_INBOUND=1 /home/nanode/monero/build/release/bin/monerod --sync-mode="$SYNC_MODE" --data-dir="$DATA_DIR" --zmq-pub tcp://"$DEVICE_IP":18083 --p2p-bind-ip 127.0.0.1 --no-igd --rpc-bind-ip="$DEVICE_IP" --rpc-bind-port=18081 --tx-proxy tor,127.0.0.1:9050 --anonymous-inbound="$ANONYMOUS_INBOUND" --confirm-external-bind --rpc-login="$RPCu:$RPCp" --rpc-ssl disabled --in-peers="$IN_PEERS" --out-peers="$OUT_PEERS" --limit-rate-up="$LIMIT_RATE_UP" --limit-rate-down="$LIMIT_RATE_DOWN" --max-log-file-size=10485760 --log-level=1 --max-log-files=1 --enable-dns-blocklist --non-interactive
