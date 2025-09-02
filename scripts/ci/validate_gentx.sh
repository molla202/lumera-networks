#!/usr/bin/env bash
# Fail fast on any error
set -euo pipefail

# ---------- chain-specific constants ----------
CHAIN_ID="lumera-testnet-2"
DENOM="ulume"
AMOUNT="1000000${DENOM}"        # 1 LUME
BINARY="lumerad"
HOME_DIR="$(pwd)/_ci_home"      # throw-away directory
GENESIS_TEMPLATE="testnet-2/genesis.json"
# ---------------------------------------------

echo "🔧 CI gentx validation started"

# 1.  fresh init
echo "• Initializing home directory at ${HOME_DIR}"
rm -rf "${HOME_DIR}"
"${BINARY}" init ci --chain-id "${CHAIN_ID}" --home "${HOME_DIR}" >/dev/null

# 2.  replace genesis with template committed in repo
cp "${GENESIS_TEMPLATE}" "${HOME_DIR}/config/genesis.json"
mkdir -p "${HOME_DIR}/config/gentx"

# 3.  iterate over every gentx file in the repo
echo "• Processing gentx files in testnet-2/gentx/"
for gentx in testnet-2/gentx/*.json; do
    echo "• processing ${gentx}"

    # 3a. extract signer pubkey (secp256k1, base64)
    signer_b64=$(jq -r '.auth_info.signer_infos[0].public_key.key' "${gentx}")
    if [[ -z "${signer_b64}" ]]; then
        echo "❌  Could not extract signer pubkey from ${gentx}"
        exit 1
    fi
    echo "  - signer pubkey: ${signer_b64} ✅"

    # 3b. convert pubkey → account address
    pubkey="{\"@type\":\"/cosmos.crypto.secp256k1.PubKey\",\"key\":\"${signer_b64}\"}"
    hex_addr=$("${BINARY}" debug pubkey $pubkey | awk '/Address:/ {print $2}')
    if [[ -z "${hex_addr}" ]]; then
        echo "❌  Could not derive account address from pubkey in ${gentx}"
        exit 1
    fi
    echo "  - hex address: ${hex_addr} ✅"

    # 3c. convert HEX → Bech32 account address (Acc HRP is auto-detected from the binary;
    #      add "--prefix lumera" if your build requires it explicitly)
    account_addr=$("${BINARY}" debug addr "${hex_addr}" | awk '/Bech32 Acc:/ {print $3}')
    if [[ -z "${account_addr}" ]]; then
        echo "❌  Could not derive Bech32 account address from pubkey in ${gentx}"
        exit 1
    fi
    echo "  - Bech32 account address: ${account_addr} ✅"

    # 3c. add account to genesis (skip if already present)
    if ! grep -q "${account_addr}" "${HOME_DIR}/config/genesis.json"; then
        "${BINARY}" genesis add-genesis-account "${account_addr}" "${AMOUNT}" \
        --home "${HOME_DIR}" >/dev/null
    fi

    # 3d. copy gentx into config/gentx
    cp "${gentx}" "${HOME_DIR}/config/gentx/"
    echo "  - ${gentx} copyied to ${HOME_DIR}/config/gentx/ ✅"
done

# 4.  collect & validate
echo "• Collecting gentx files"
"${BINARY}" genesis collect-gentxs --home "${HOME_DIR}" >/dev/null
echo "  - gentx files collected ✅"

echo "• Validating genesis file"
"${BINARY}" genesis validate-genesis --home "${HOME_DIR}"
echo "  - genesis file valid ✅"

echo "✅✅✅ All gentx files valid ✨"
