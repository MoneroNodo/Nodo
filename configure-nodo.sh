#!/bin/bash

. /home/nodo/common.sh

_v=/home/nodo/variables
# Restore config
showtext "Merge config.json"

# Use repo-specified variables
force_vars=(
.config.monero_port
.config.monero_rpc_port
.config.monero_public_port
.config.i2p_port
.config.tor_port
.config.lws_port
.config.zmq_port
)
# Remove deprecated variables
deprecated_vars=(.config.sync_mode)

# Merge user and repo config
remove_vars=("${force_vars[@]} ${deprecated_vars[@]}")
for key in "${remove_vars[@]}"; do
        keys+="${key}, "
        remove_list="${keys%, }"
done

merge_config() {
	jq -s ".[0] * (.[1] | del(${remove_list})) | {config: .config}" "${_v}"/config.json "${_v}"/config_retain.json > "${_v}"/config.merge.json
}
if merge_config;then
        cp -f "${_v}"/config.merge.json "${_v}"/config.json
else
        cp -f "${_v}"/config_retain.json "${_v}"/config.json
fi

chown nodo:nodo "${_v}"/config.json

showtext "User configuration restored"
