#!/usr/bin/env bash
# Check that the deposit contract really is deployed at the address
# metadata/config.yaml advertises, and that the chain/network ids in the config
# agree with the live execution node.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
META="$ROOT/metadata"
CONFIG="$META/config.yaml"

fail=0
ok()  { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }

# DEPOSIT_CONTRACT_ADDRESS is an unquoted hex literal, which a YAML parser turns
# into an integer. Read the raw line instead so the checksummed form survives.
cfg_get() { sed -n "s/^$1:[[:space:]]*\([^[:space:]#]*\).*$/\1/p" "$CONFIG" | head -n1; }

rpc_call() {
  curl -sS -m 20 -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$2\",\"params\":$3}" "$1"
}

addr="$(cfg_get DEPOSIT_CONTRACT_ADDRESS)"
chain_id="$(cfg_get DEPOSIT_CHAIN_ID)"
net_id="$(cfg_get DEPOSIT_NETWORK_ID)"
rpc="$(jq -r '.rpc[0]' "$META/chain.json")"

# deposit_contract.txt must not disagree with the config.
txt="$(tr -d '[:space:]' < "$META/deposit_contract.txt")"
if [ "$txt" = "$addr" ]; then
  ok "deposit_contract.txt matches config.yaml"
else
  bad "deposit_contract.txt=$txt but config.yaml=$addr"
fi

case "$addr" in
  0x*) ;;
  *) bad "DEPOSIT_CONTRACT_ADDRESS is not set to an address ($addr)"; exit $fail ;;
esac

# The contract must actually exist on the chain the config points at.
code="$(rpc_call "$rpc" eth_getCode "[\"$addr\",\"latest\"]" | jq -r '.result // empty')"
size=$(( (${#code} - 2) / 2 ))
if [ -z "$code" ] || [ "$code" = "0x" ]; then
  bad "no contract deployed at $addr on $rpc"
else
  ok "deposit contract deployed at $addr ($size bytes)"
fi

# ...and the ids in the config must be the ids that node reports.
live_chain="$(rpc_call "$rpc" eth_chainId '[]' | jq -r '.result // empty')"
live_net="$(rpc_call "$rpc" net_version '[]' | jq -r '.result // empty')"

if [ -n "$live_chain" ] && [ "$((live_chain))" -eq "$chain_id" ]; then
  ok "DEPOSIT_CHAIN_ID $chain_id matches the node"
else
  bad "DEPOSIT_CHAIN_ID=$chain_id but $rpc reports $((${live_chain:-0}))"
fi

if [ "$live_net" = "$net_id" ]; then
  ok "DEPOSIT_NETWORK_ID $net_id matches the node"
else
  bad "DEPOSIT_NETWORK_ID=$net_id but $rpc reports ${live_net:-none}"
fi

exit $fail
