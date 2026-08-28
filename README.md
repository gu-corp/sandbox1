# sandbox1 metadata

Sandbox1 — the development network. Chain ID `1337`, Clique
proof-of-authority, 5-second blocks. This is where the PoA → PoS migration is
being rehearsed: unlike joc and joct, sandbox1 has a deployed deposit contract
and a real consensus-layer config.

> **The p2p network id is `1456260212`, not the chain ID `1337`.** Geth defaults
> `--networkid` to the genesis `chainId`, so it must be passed explicitly.
>
> **Chain ID `1337` is also the default for Ganache, Hardhat and Anvil.** Wallets
> and tooling configured for a local dev chain can collide with this network.

## Status

**Merged.** The beacon chain reached genesis and the execution layer crossed
`TERMINAL_TOTAL_DIFFICULTY` on 2026-08-27. As of 2026-08-28:

| | |
|---|---|
| `MIN_GENESIS_TIME` | `1787652600` — 2026-08-25T10:10:00Z |
| `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT` | `5` |
| Deposits in the contract | **6** (`get_deposit_count()`) |
| `get_deposit_root()` | `0xadc1fbd3…b400` |
| `TERMINAL_TOTAL_DIFFICULTY` | `60103838` — reached |
| Terminal PoW block | `31418731`, total difficulty `60103838` |
| First PoS block | `31418732`, 2026-08-27T15:46:33Z (`difficulty: 0x0`) |

Total difficulty is frozen at `60103838` and every block since 31418732 carries
difficulty 0. `CAPELLA_FORK_EPOCH` is set to `2151`; Deneb and later remain
disabled (`2**64-1`).

Re-check with:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockByNumber","params":["latest",false]}' \
  https://rpc-1.sandbox1.japanopenchain.org:8545 | jq '.result | {number, difficulty, totalDifficulty}'
```

## Genesis information

```yaml
chain_id: 1337
network_id: 1456260212        # geth --networkid — differs from chain_id
genesis_time: 1543235253      # 2018-11-26T12:27:33Z, same as joc and joct
genesis_hash: 0xb9f3edbea733300355a191e5f7fa9e39603abddd8a31bc63d6bbb1987d36ca3f
genesis_state_root: 0xc821f27902b258391f993d2953ab4956fb51ff3ba3be06e7a49f27611512a39e
gas_limit: 470000000
clique:
  period: 5
  epoch: 30000                # inferred, see below
  genesis_signers:
    - 0xba82df33044b90a6d76591aef9fb4870d6b53c20
berlin_block: 12842808        # note: NOT the same block as london
london_block: 17553835
```

## How much of this is verified

The header fields and the allocation in
[`metadata/genesis.json`](metadata/genesis.json) were reconstructed from the
live chain before an official file was available, and are now proven: CI runs
`geth init` on the file and it reproduces the genesis hash above. Because the
state root commits to the whole allocation, that check being green **proves the
allocation and every header field are exactly right**.

The `config` block does not enter the genesis hash and so could not be proven
the same way; it comes from the authoritative sandbox1 genesis file.

That distinction is not academic here. `berlinBlock` is **12842808, not the same
block as `londonBlock`** — joc and joct activate the two together, and following
that convention produced a wrong value that every check still passed. Anything
in `config` has to come from the source of truth, never from a pattern.

`metadata/genesis.json` carries both `MuirGlacierBlock` and `muirGlacierBlock`,
as the official file does. Go's JSON decoding is case-insensitive, so the two
map to the same field and the duplicate is harmless; it is kept for fidelity.

One thing remains unverified: **no bootnodes are published**, so there is no
`metadata/enodes.yaml`.

## Files

| File | Contents |
|---|---|
| [`metadata/genesis.json`](metadata/genesis.json) | Execution-layer genesis. Feed to `geth init`. |
| [`metadata/genesis_details.yaml`](metadata/genesis_details.yaml) | Genesis hash, state root, clique params, fork blocks, provenance |
| [`metadata/config.yaml`](metadata/config.yaml) | Consensus-layer (beacon chain) config |
| [`metadata/deposit_contract.txt`](metadata/deposit_contract.txt) | Deposit contract address |
| [`metadata/chain.json`](metadata/chain.json) | EIP-155 chain metadata — id, RPC endpoint, native currency, explorer |

## Endpoints

| | |
|---|---|
| RPC | `https://rpc-1.sandbox1.japanopenchain.org:8545` |
| Explorer | https://rpc-1.sandbox1.japanopenchain.org (Blockscout, same host, port 443) |

The endpoint documented in `gu-corp/gu-sandbox-chain-docs` and in
`gu-ethereum-sdk`'s chain constants — `https://sandbox1.japanopenchain.org:8545/`
with chain ID 99999 — does not resolve. Both should be updated.

## Run a node

```bash
geth init --datadir ~/.sandbox1 metadata/genesis.json
geth --datadir ~/.sandbox1 --networkid 1456260212 --syncmode full
```

No `--bootnodes` value can be given until bootnodes are published; peer with a
known node directly in the meantime.

Verify the config matches the live chain with `scripts/verify_genesis.sh`
and `scripts/check_deposit_contract.sh`.

## License

CC0 1.0 Universal. See [`LICENSE`](LICENSE).
