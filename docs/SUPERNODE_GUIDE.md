# Lumera SuperNode Operator Guide

> Scope update (July 2025) – This revision aligns the guide with the latest `supernode init` command defaults and the new dual‑source stake validation flow. Follow it exactly to avoid registration failures.
> 

---

## 1. Quick Path (High‑Level)

1. ✅ **Validator exists** (already installed, set up, and in `BOND_STATUS_BONDED`). If you don’t have one yet, finish the validator guide first.
2. ⚖️ **Meet the minimum stake (choose one path)**
    - **Path A — Self‑Stake**: acquire and self‑delegate the required LUME.
    - **Path B — Foundation‑Supported**:
        
        1. Generate a **brand‑new address** on the validator host (no prior balance, no existing account).
        
        2. Ask the Foundation to **fund** that address ***or*** convert the transfer into a **vesting account** (`create‑delayed‑account` / `create‑permanently‑locked‑account`).
        
        3. Delegate *from that new address* to your validator.
        
3. 📦 Install the SuperNode binary on a separate host.
4. 🛠️ **Init the SuperNode config**
    - Path A: run `supernode init` and create a brand‑new key.
    - Path B: run `supernode init --recover` with the mnemonic of the address used in step 2‑B.
5. 📝 **Register the SuperNode** *from the **validator** host* – transaction **must** be signed by the **validator operator account**.

---

## 2. System Requirements

| Component | Minimum | Recommended |
| --- | --- | --- |
| **CPU** | 8 vCPU | 16 vCPU |
| **RAM** | 16 GB | 64 GB |
| **Storage** | 1 TB NVMe | 4 TB NVMe |
| **Network** | 1 Gbps | 5 Gbps |
| **OS** | Ubuntu 22.04 LTS+ | Same |

Open inbound **4444/tcp** (gRPC API) and **4445/tcp** (P2P).

---

## 3. Stake Preparation

### 3.1 Check Current Self‑Stake

```bash
VALOPER=$(lumerad keys show <val_key> --bech val -a)
lumerad q staking validator $VALOPER
```

Confirm ≥ required tokens (`25 000 LUME` mainnet / `10 000 LUME` testnet).

### 3.2 Path A — Pure Self‑Stake

Self‑delegate as needed:

```bash
lumerad tx staking delegate $VALOPER <amount>ulume --from <val_key> --gas auto --fees 5000ulume --chain-id lumera-mainnet-1
```

<details>
<summary><strong>Testnet Example</strong></summary>

```bash
lumerad tx staking delegate $VALOPER <amount>ulume --from <val_key> --gas auto --fees 5000ulume --chain-id lumera-testnet-2
```
</details>

### 3.3 Path B — Foundation‑Supported Delegation

1. **Create an empty account** on the validator host:

```bash
lumerad keys add sn_delegate_key --keyring-backend file
```

2. **Foundation transfer** (example – delayed vesting):

```bash
# broadcasted by the Foundation, shown here for completeness
lumerad tx vesting create-delayed-account <new_addr> 25000000000000ulume --from foundation --chain-id lumera-mainnet-1 --fees 5000ulume
```

3. **Delegate from the new address**:

```bash
lumerad tx staking delegate $VALOPER 25000000000000ulume --from sn_delegate_key --gas auto --fees 5000ulume --chain-id **lumera-testnet-2**
```

<details>
<summary><strong>Testnet Example</strong></summary>

```bash
lumerad tx staking delegate $VALOPER 10000000000000ulume --from sn_delegate_key --gas auto --fees 5000ulume --chain-id lumera-mainnet-1
```
</details>    

> Dual‑Source check: the network will now sum self‑delegation + delegation from <new_addr> when validating SuperNode eligibility.
> 

---

## 4. Install SuperNode Binary

```bash
sudo curl -L -o /usr/local/bin/supernode \
  https://github.com/LumeraProtocol/supernode/releases/latest/download/supernode-linux-amd64
sudo chmod +x /usr/local/bin/supernode
supernode version
```

---

## 5. Initialize the SuperNode Configuration

### Defaults (from `init.go`)

| Option | Default |
| --- | --- |
| `keyring-backend` | `os` |
| `supernode-addr` | `0.0.0.0` |
| `supernode-port` | `4444` |
| `lumera-grpc` | `localhost:9090` |
| `chain-id` | `lumera-mainnet-1` |

> If you don’t want to use local Lumera node for API access, add  `--lumera-grpc https://lumera.grpc_addr` (mainnet) or `--lumera-grpc https://lumera.testnet.grpc_addr` (testnet) to the following commnds
> 

### 5.1 Path A — Create a New Key

```bash
supernode init --key-name mySNKey --chain-id lumera-mainnet-1
```

<details>
<summary><strong>Testnet Example</strong></summary>

```bash
supernode init --key-name mySNKey --chain-id **lumera-testnet-2**
```
</details>    

Follow the interactive prompts (**or** pass `-y` plus flags for non‑interactive setup).

### 5.2 Path B — Recover the Foundation Delegation Address

```bash
supernode init --key-name sn_delegate_key --recover --chain-id lumera-mainnet-1
```

<details>
<summary><strong>Testnet Example</strong></summary>

```bash
supernode init --key-name sn_delegate_key --recover --chain-id lumera-testnet-2
```
</details>    

Follow the interactive prompts (**or** pass `-y` plus flags for non‑interactive setup).

> Important – this key must match the address that delegated in §3.3, otherwise eligibility will fail.
> 

The command creates `~/.supernode/config.yml`. Review and, if needed, edit it manually.

---

## 6. Run SuperNode as a Service

```bash
sudo tee /etc/systemd/system/supernode.service <<EOF
[Unit]
Description=Lumera SuperNode
After=network-online.target

[Service]
User=%i
ExecStart=/usr/local/bin/supernode start --home /home/%i/.supernode
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now supernode@$(whoami)
journalctl -u supernode@$(whoami) -f
```

---

## 7. Register the SuperNode (on Validator Host)

```bash
VALOPER=$(lumerad keys show <val_key> --bech val -a)
SN_ENDPOINT="<sn_ip>:4444"
SN_ACCOUNT="$(lumerad keys show <sn_key_or_sn_delegate_key> -a)"

lumerad tx supernode register-supernode \
  $VALOPER $SN_ENDPOINT $SN_ACCOUNT \
  --from <val_key> --chain-id lumera-mainnet-1 \
  --gas auto --fees 5000ulume
```

<details>
<summary><strong>Testnet Example</strong></summary>

```bash
VALOPER=$(lumerad keys show <val_key> --bech val -a)
SN_ENDPOINT="<sn_ip>:4444"
SN_ACCOUNT="$(lumerad keys show <sn_key_or_sn_delegate_key> -a)"

lumerad tx supernode register-supernode \
  $VALOPER $SN_ENDPOINT $SN_ACCOUNT \
  --from <val_key> --chain-id lumera-testnet-2 \
  --gas auto --fees 5000ulume
```
</details>    

- The **`-from`** signer *must* be the **validator operator account**.
- Eligibility is checked immediately using **self‑delegation + SN‑account delegation**.

---

## 8. Verification

```bash
lumerad q supernode get-super-node $VALOPER --node https://rpc.lumera.io:443
```

Status should be `ACTIVE`. If you see `INSUFFICIENT_STAKE`, re‑check §3.

---

## 9. Monitoring & Troubleshooting

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| `ELIGIBILITY_FAILED` on registration | Combined stake < minimum | Verify delegations (§3) |
| SuperNode stuck `DISABLED` | Validator fell out of active set **and** stake below threshold | Add stake or re‑enter active set |
| gRPC errors | Wrong `lumera.grpc_addr` | Point to local node or official API |

---

## 10. Security Best Practices

- **Separate Hosts** – keep validator keys and SuperNode keys on different machines.
- **OS Keyring** – default `os` backend leverages system credential storage; use it in production.
- **Backups** – back up `~/.supernode` and validator keyring separately.

---

© 2025 Lumera Protocol – Guide version 1.1