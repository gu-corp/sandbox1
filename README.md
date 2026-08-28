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
difficulty 0.

### Fork schedule

`PRESET_BASE: gnosis` sets `SLOTS_PER_EPOCH` to **16**, so one epoch is
`16 * 5 = 80` seconds — not the 384s of the mainnet preset. Beacon genesis was
`1787676703` (2026-08-25T16:51:43Z), the timestamp of the eth1 block carrying
the 5th deposit plus `GENESIS_DELAY`.

| Fork | Epoch | Activates | EL counterpart |
|---|---|---|---|
| Altair | `5` | 2026-08-25T16:58:23Z | — |
| Bellatrix | `10` | 2026-08-25T17:02:23Z | merge at TTD, block 31418732 |
| Capella | `2151` | 2026-08-27T16:39:43Z | `shanghaiTime` — block 31419366, first `withdrawalsRoot` |
| Deneb | `2579` | 2026-08-28T02:10:23Z | `cancunTime` |
| Electra | `2595` | 2026-08-28T02:31:43Z | `pragueTime` — forkId `0xb22f09bb` |

Fulu and later remain disabled (`2**64-1`).

Both epochs were checked against the execution layer rather than assumed —
`eth_config` on the node reports the same two activation timestamps:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_config","params":[]}' \
  https://rpc-1.sandbox1.japanopenchain.org:8545 | jq '{current:.result.current.activationTime, next:.result.next.activationTime}'
```

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
terminal_total_difficulty: 60103838   # reached; first PoS block 31418732
shanghai_time: 1787848783     # 2026-08-27T16:39:43Z, = CAPELLA_FORK_EPOCH 2151
cancun_time: 1787883023       # 2026-08-28T02:10:23Z, = DENEB_FORK_EPOCH 2579
prague_time: 1787884303       # 2026-08-28T02:31:43Z, = ELECTRA_FORK_EPOCH 2595
deposit_contract_address: 0xd7e2921Fe84Ffb29AD793F5E5f89C5C8A452c5F2
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

[`metadata/genesis.ssz`](metadata/genesis.ssz) is the beacon chain genesis
state, taken from the beacon node's own `/eth/v2/debug/beacon/states/genesis`.
It is not derived: the state could be rebuilt from the deposits on the eth1
chain, but that is exactly the kind of reconstruction the `berlinBlock` lesson
warns against, so it comes from the node. `scripts/check_genesis_ssz.sh` decodes
its header and checks `genesis_time` and `genesis_validators_root` against the
node, then checks every key in `config.yaml` against `/eth/v1/config/spec` and
every fork epoch against `/eth/v1/config/fork_schedule`.

The deposit contract's deployment block was **not** supplied; it was measured,
and it took some care. The node keeps no archive state — `eth_getCode` at an old
block returns `not supported` — so the usual binary search is out, and `debug_`
and `trace_` are both disabled. The explorer names block `31377725` and creation
transaction `0x070517ae…c58d`, and the node's own receipt for that transaction
confirms the block and its hash.

But that receipt's `contractAddress` is `0x0a0fb3f2…bc34`, a **factory**, not
the deposit contract, and none of the transaction's logs come from the deposit
address. The contract was created by an internal `CREATE`, which no public RPC
on this node will show. So it was confirmed arithmetically instead: a contract
address is `keccak256(rlp([creator, nonce]))[12:]`, and from that factory,

```
nonce 1 -> 0xb2ec4469…a9d9     nonce 3 -> 0xd7e2921f…c5f2   <- deposit contract
nonce 2 -> 0xfAEf3b65…6b83d    nonce 4 -> 0x9C7962aE…fc31
```

Nonces 1, 2 and 4 are exactly three of the addresses that emitted logs in that
transaction, according to the node's own receipt. Nonces are sequential, so the
nonce-3 creation cannot have happened later than the nonce-4 one — the deposit
contract was created in that transaction, in block `31377725`. Only the list of
internal creations came from the explorer; everything load-bearing came from the
node.

Both layers now publish a bootnode, supplied by the operators:
[`metadata/enodes.yaml`](metadata/enodes.yaml) for execution and
[`metadata/bootstrap_nodes.yaml`](metadata/bootstrap_nodes.yaml) for consensus.
The consensus one is a dedicated discv5 bootnode — udp only, no tcp and no
`eth2` entry. The two are on different hosts.

Its liveness is **proven, not assumed**. A TCP connect only shows a port is
open, and discovery runs over UDP where a connect shows nothing at all: there is
no handshake, so `nc -zu` reports success against a black hole. Instead
[`scripts/discv5_probe.py`](scripts/discv5_probe.py) sends a real discv5 packet.
The masking key of such a packet is the *recipient's* node id, which is
keccak256 of the public key in the ENR, so only a node that agrees its id is
that can unmask it — and it must answer `WHOAREYOU`. Getting that reply back
binds the key in the record to whatever is actually listening. CI runs it
weekly, so the node going away surfaces on its own.

The execution-layer bootnode is held to a **weaker** standard, and it is worth
knowing which is which. There is no cheap equivalent of the `WHOAREYOU` trick
for devp2p: proving that node id belongs to that address needs a full RLPx
handshake, ECIES over secp256k1 ECDH. So `enodes.yaml` is only checked for a
well-formed URL and a port that accepts TCP — enough to catch rot, not enough
to prove identity.

## Files

| File | Contents |
|---|---|
| [`metadata/genesis.json`](metadata/genesis.json) | Execution-layer genesis. Feed to `geth init`. |
| [`metadata/genesis_details.yaml`](metadata/genesis_details.yaml) | Genesis hash, state root, clique params, fork blocks, provenance |
| [`metadata/config.yaml`](metadata/config.yaml) | Consensus-layer (beacon chain) config |
| [`metadata/genesis.ssz`](metadata/genesis.ssz) | Beacon chain genesis state. Feed to a consensus client. |
| [`metadata/enodes.yaml`](metadata/enodes.yaml) | Execution-layer bootnode enode URLs |
| [`metadata/bootstrap_nodes.yaml`](metadata/bootstrap_nodes.yaml) | Consensus-layer bootnode ENRs |
| [`scripts/discv5_probe.py`](scripts/discv5_probe.py) | Proves a discv5 node is alive by making it answer `WHOAREYOU` |
| [`metadata/deposit_contract.txt`](metadata/deposit_contract.txt) | Deposit contract address |
| [`metadata/deposit_contract_block.txt`](metadata/deposit_contract_block.txt) | Eth1 block the deposit contract was deployed in |
| [`metadata/deposit_contract_block_hash.txt`](metadata/deposit_contract_block_hash.txt) | Hash of that block |
| [`metadata/chain.json`](metadata/chain.json) | EIP-155 chain metadata — id, RPC endpoint, native currency, explorer |

## Endpoints

| | |
|---|---|
| Execution RPC | `https://rpc-1.sandbox1.japanopenchain.org:8545` |
| Beacon API | `https://rpc-1.sandbox1.japanopenchain.org:3500` (Lighthouse; load-balanced across several nodes) |
| Explorer | https://rpc-1.sandbox1.japanopenchain.org (Blockscout, same host, port 443) |

The endpoint documented in `gu-corp/gu-sandbox-chain-docs` and in
`gu-ethereum-sdk`'s chain constants — `https://sandbox1.japanopenchain.org:8545/`
with chain ID 99999 — does not resolve. Both should be updated.

## Run a node

Both layers are required — the chain is post-merge, so an execution client on
its own will not follow the head.

### Execution layer

```bash
geth init --datadir ~/.sandbox1 metadata/genesis.json
geth --datadir ~/.sandbox1 --networkid 1456260212 --syncmode full \
     --authrpc.jwtsecret ~/.sandbox1/jwt.hex \
     --bootnodes "$(sed -n 's/^-[[:space:]]*\(enode:\/\/[^[:space:]#]*\).*$/\1/p' metadata/enodes.yaml | paste -sd, -)"
```

`--networkid` must be passed explicitly: geth would otherwise default it to the
genesis `chainId`, which is `1337`, not the `1456260212` this network uses.

### Consensus layer

`genesis.ssz` is not optional. `genesis_validators_root` feeds `ForkDigest`,
which names every gossip topic, so a client without it cannot join at all.

```bash
lighthouse beacon_node \
  --testnet-dir metadata \
  --boot-nodes "$(sed -n 's/^-[[:space:]]*\(enr:[^[:space:]#]*\).*$/\1/p' metadata/bootstrap_nodes.yaml | paste -sd, -)" \
  --execution-endpoint http://localhost:8551 \
  --execution-jwt ~/.sandbox1/jwt.hex
```

`--testnet-dir metadata` picks up `config.yaml` and `genesis.ssz` from this
repo. Other clients want the same two files under different flag names.

### Verify

```bash
scripts/verify_genesis.sh          # geth init reproduces the genesis hash
scripts/check_deposit_contract.sh  # deposit contract is deployed, ids match
scripts/check_genesis_ssz.sh       # genesis.ssz and config.yaml match the beacon node
scripts/check_bootnodes.sh         # published bootnodes are well-formed and answer
```

`check_bootnodes.sh` dials TCP where an ENR advertises it and runs
`discv5_probe.py` where it advertises UDP, so a udp-only bootnode is checked
properly rather than skipped.

## License

CC0 1.0 Universal. See [`LICENSE`](LICENSE).
