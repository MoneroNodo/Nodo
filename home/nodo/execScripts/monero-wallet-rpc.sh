#!/bin/bash

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

{
read -r MONERO_PUBLIC_PORT
read -r RPC_ENABLED
read -r RPCu
read -r RPCp
} < <(
jq -r '.config | .monero_public_port, .rpc_enabled, .rpcu, .rpcp' < $CONFIG_FILE
)

if [ "$RPC_ENABLED" == "TRUE" ]; then
	rpc_args="--daemon-login=\"$RPCu:$RPCp\""
fi

eval sudo -u moneropay /home/nodo/bin/monero-wallet-rpc --trusted-daemon --daemon-address 127.0.0.1:"$MONERO_PUBLIC_PORT" \
	"$rpc_args" --disable-rpc-login --non-interactive --rpc-bind-port=34512 --wallet-dir /opt/moneropay/
