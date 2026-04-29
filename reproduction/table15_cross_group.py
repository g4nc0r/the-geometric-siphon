"""
Table 15: Cross-group token decomposition.

Reproduces §5.2.3 Table 15 from supplementary/closed-form-decomposition-cache.json
(581 transaction receipts). Partial reproduction: emits per-token dust deltas
from the receipt cache. The 9-row paper table additionally needs per-receipt
depositor attribution, which requires the address → depositor-emoji link
(not in the deposit). See ../README.md for the receipt-cache schema.

Per-token dust on a rebalance is:

    dust_token = collected_token + swap_in_token - minted_token - swap_out_token

Positive values = donated to the contract dust pool; negative = absorbed.
"""

import json
from collections import defaultdict

from _common import SUPP_DIR

# Aerodrome Slipstream NonfungiblePositionManager event topic hashes.
DECREASE_LIQ = "0x26f6a048ee9138f2c0ce266f322cb99228e8d619ae2bff30c67f8dcf9d2377b4"
COLLECT      = "0x40d0efd1a53d60ecbf40971b9daf7dc90178c3aadc7aab1765632738fa8b8f01"
INCREASE_LIQ = "0x3067048beee31b25b2f1681f88dac838c8bba36af25bfb2b7cf7473a5847e35f"
SWAP         = "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67"


def signed256(hex32):
    """Decode a 32-byte hex string as a signed int256 (two's complement)."""
    v = int(hex32, 16)
    return v - (1 << 256) if v & (1 << 255) else v


def parse_receipt(receipt):
    """Extract per-receipt dust deltas. Returns {pool, dust0, dust1} or None."""
    if receipt.get("status") != "0x1":
        return None

    collected = {"amount0": 0, "amount1": 0}
    minted = {"amount0": 0, "amount1": 0}
    swapped_out = {"amount0": 0, "amount1": 0}
    swapped_in = {"amount0": 0, "amount1": 0}

    pool_addr = None

    for log in receipt.get("logs", []):
        topics = log.get("topics", [])
        if not topics:
            continue
        topic0 = topics[0]
        data = log.get("data", "0x")

        if topic0 in (INCREASE_LIQ, COLLECT) and len(data) >= 2 + 64 * 3:
            amt0 = int(data[2 + 64:2 + 128], 16)
            amt1 = int(data[2 + 128:2 + 192], 16)
            target = minted if topic0 == INCREASE_LIQ else collected
            target["amount0"] += amt0
            target["amount1"] += amt1

        elif topic0 == SWAP and len(data) >= 2 + 64 * 2:
            # V3 Swap convention: amount > 0 = pool received, < 0 = pool sent.
            a0 = signed256(data[2:2 + 64])
            a1 = signed256(data[2 + 64:2 + 128])
            if a0 > 0:
                swapped_out["amount0"] += a0
                swapped_in["amount1"] += -a1
            else:
                swapped_in["amount0"] += -a0
                swapped_out["amount1"] += a1
            pool_addr = log.get("address", "").lower()

    return {
        "pool": pool_addr,
        "dust0": collected["amount0"] + swapped_in["amount0"]
                 - minted["amount0"] - swapped_out["amount0"],
        "dust1": collected["amount1"] + swapped_in["amount1"]
                 - minted["amount1"] - swapped_out["amount1"],
    }


def main():
    cache_path = SUPP_DIR / "closed-form-decomposition-cache.json"
    if not cache_path.exists():
        print(f"ERROR: {cache_path} not found.")
        return

    with open(cache_path) as f:
        cache = json.load(f)

    parsed_count = 0
    pool_counter = defaultdict(int)
    nonzero_dust = 0

    for receipt in cache.values():
        result = parse_receipt(receipt)
        if result is None:
            continue
        parsed_count += 1
        if result["pool"]:
            pool_counter[result["pool"]] += 1
        if result["dust0"] != 0 or result["dust1"] != 0:
            nonzero_dust += 1

    print("# Table 15: Cross-group token decomposition\n")
    print(f"Source: supplementary/closed-form-decomposition-cache.json "
          f"({len(cache)} receipts).\n")
    print(f"Parsed cleanly: {parsed_count} / {len(cache)}")
    print(f"With non-zero per-token dust: {nonzero_dust}")
    print(f"Distinct pools touched: {len(pool_counter)}")
    print()

    print("Top 12 pools by receipt count:\n")
    print("| Pool address | Receipts |")
    print("|---|---|")
    for pool, n in sorted(pool_counter.items(), key=lambda x: -x[1])[:12]:
        print(f"| {pool} | {n:,} |")


if __name__ == "__main__":
    main()
