#!/bin/bash

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

{
read -r MONERO_PORT
read -r MONERO_PUBLIC_PORT
read -r RPC_ENABLED
read -r RPC_PORT
read -r RPCu
read -r RPCp
read -r IN_PEERS
read -r OUT_PEERS
read -r LIMIT_RATE_UP
read -r LIMIT_RATE_DOWN
read -r DATA_DIR
read -r TORPROXY_ENABLED
read -r I2P_ENABLED
read -r I2P_PORT
read -r I2P_ADDRESS
read -r TOR_ENABLED
read -r TOR_PORT
read -r TOR_ADDRESS
read -r DATA_DIR
read -r SYNC_MODE
read -r ZMQ_PUB
} < <(
	jq '.config | .monero_port, .monero_public_port, .rpc_enabled, .monero_rpc_port, .rpcu, .rpcp, .in_peers, .out_peers, .limit_rate_up, .limit_rate_down, .data_dir, .torproxy_enabled, .i2p_enabled, .i2p_port, .i2p_address, .tor_enabled, .tor_port, .tor_address, .data_dir, .sync_mode, .zmq_pub' $CONFIG_FILE
)

DEVICE_IP="0.0.0.0"

#Start Monerod
if [ "$TORPROXY_ENABLED" == "TRUE" ]; then
	cln_flags="--proxy=127.0.0.1:9050 "
fi

if [ "$I2P_ENABLED" == "TRUE" ]; then
	i2p_args="--tx-proxy=i2p,127.0.0.1:4447,32,disable_noise ${I2P_ADDRESS:+--anonymous-inbound=$I2P_ADDRESS,127.0.0.1:$I2P_PORT} "
fi

if [ "$TOR_ENABLED" == "TRUE" ]; then
	tor_args="--tx-proxy=tor,127.0.0.1:9050,32,disable_noise ${TOR_ADDRESS:+--anonymous-inbound=$TOR_ADDRESS:$TOR_PORT,127.0.0.1:$TOR_PORT} "
fi

if [ "$RPC_ENABLED" == "TRUE" ]; then
	rpc_args="--rpc-restricted-bind-ip=\"$DEVICE_IP\" --rpc-restricted-bind-port=\"$RPC_PORT\" ${RPCu:+--rpc-login=\"$RPCu:$RPCp\"} "
fi

eval /home/nodo/bin/monerod "$i2p_args$tor_args$rpc_args$cln_flags" --db-sync-mode="$SYNC_MODE" --data-dir="$DATA_DIR" --zmq-pub tcp://"$DEVICE_IP":"$ZMQ_PUB" --in-peers="$IN_PEERS" --out-peers="$OUT_PEERS" --limit-rate-up="$LIMIT_RATE_UP" --limit-rate-down="$LIMIT_RATE_DOWN" --max-log-file-size=10485760 --log-level=0 --max-log-files=1 --enable-dns-blocklist --p2p-bind-port="$MONERO_PORT" --non-interactive
