#!/bin/bash

#shellcheck source=home/nodo/common.sh
. /home/nodo/common.sh

DATA_DIR=$(getvar "data_dir")/light_wallet_server
PORT=8135

base="/home/nodo/bin/monero-lws-daemon --daemon tcp://127.0.0.1:18082 --db-path $DATA_DIR --admin-rest-server http://127.0.0.1:${PORT}/admin --rest-server http://127.0.0.1:${PORT}/basic"

# in case version too old
eval "$base --auto-accept-creation" \
	|| eval "$base"
