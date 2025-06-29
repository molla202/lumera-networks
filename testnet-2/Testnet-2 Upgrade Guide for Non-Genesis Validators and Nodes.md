This guide provides instructions for all non-genesis validators and node operators on how to upgrade to `testnet-2`.

## Key Principle: Staggered Start

To ensure a seamless transition and maintain network availability, we are using a two-phase launch:

1.  **Genesis Validators First:** A core set of genesis validators will stop their `testnet-1` nodes, wipe their state, and use the new `v1.6.0` binary, `genesis.json` and `claims.csv` to launch `testnet-2` at the designated genesis time.
2.  **All Other Operators:** All other validators and node operators will wait until **after** `testnet-2` is live before performing the upgrade. This ensures `testnet-1` remains active until the new testnet is confirmed to be stable.

**DO NOT follow these instructions until after the official genesis time.**

---

## Upgrade Instructions

**Action Time:** If you are NOT genesis validator, perform steps **2-5** only **AFTER** `2025-07-02T16:00:00Z`.

### **Step 1: Download Required Files**

You will need the following files. Please download them from the official release page (links to be provided):

*   **`lumerad` v1.6.0 binary:** The new node software - https://github.com/LumeraProtocol/lumera/releases/download/v1.6.0/lumera_v1.6.0_linux_amd64.tar.gz
*   **`genesis.json`:** The new testnet's genesis file - https://raw.githubusercontent.com/LumeraProtocol/lumera-networks/refs/heads/master/testnet-2/genesis.json
*   **`claims.csv`:** The updated claims file for `testnet-2` - https://raw.githubusercontent.com/LumeraProtocol/lumera-networks/refs/heads/master/testnet-2/claims.csv
  
> You can downlaod these files BEFORE `2025-07-02T16:00:00Z`

### **Step 2: Stop Your Node**

Stop your `lumerad` service. If you are using `systemd`, the command is:

```bash
sudo systemctl stop lumerad
```

### **Step 3: Wipe Chain Data**

**This is a critical step and will erase your `testnet-1` data.** This is necessary to join the new chain.

```bash
lumerad tendermint unsafe-reset-all
rm -rf ~/.lumera/wasm
```

### **Step 4: Replace Network Files**

1.  **Replace the Binary:** Move the new `lumerad` v1.6.0 binary to the appropriate location (e.g., `/usr/local/bin/lumerad` OR ~/.lumera/), replacing the old version.
2.  **Replace Genesis File:** Copy the new `genesis.json` file into your node's configuration directory, replacing the existing one.
```bash
cp /path/to/new/genesis.json ~/.lumera/config/genesis.json
```
3.  **Place Claims File:** Copy the new `claims.csv` file into your node's configuration directory.
```bash
cp /path/to/new/claims.csv ~/.lumera/config/claims.csv
```

#### If you are using `cosmovisor`

```bash
mkdir -p ~/.lumera/cosmovisor/genesis/bin
cp /path/to/new/lumerad ~/.lumera/cosmovisor/genesis/bin/lumerad
unlink ~/.lumera/cosmovisor/current
ln -s ~/.lumera/cosmovisor/genesis ~/.lumera/cosmovisor/current
```

### **Step 5: Start Your Node**

Now, you can restart your node. It will connect to `testnet-2` peers and begin syncing from the new genesis block.

```bash
sudo systemctl start lumerad
```

By following this procedure after the genesis time, you will successfully join `testnet-2` without causing any disruption to the transition process.
