# Distriba v0 Parameter Freeze

This document freezes all economic and protocol parameters for Distriba v0.

Unless explicitly governed through timelock mechanisms, these values MUST NOT
change for the lifetime of v0.

---

## Activation & Licensing

- Activation fee (initial): **$50 USDC**
- License duration: **180 days**
- Licenses per wallet (v0): **1**
- Renewal allowed: **Yes**
- Renewal fee: **Same as activation fee**

---

## Beta Pricing Ladder (Fixed)

Activation fee during beta:
- 0–100 miners: **$10**
- 101–200 miners: **$25**
- 201+ miners: **$50**

Pricing advances automatically and never decreases.

---

## Entitlement & Emissions

- Entitlement accrual: **Linear over license duration**
- Lifetime earning cap per license: **1.5× activation fee (in DSRX units)**
- Entitlement unit: **Abstract (non-USD)**
- Emissions schedule: **Time-based, capped**

---

## Vesting Options

Default vesting:
- Duration: **60 days**
- Penalty: **0%**

Accelerated vesting options:
- 30 days: **5% penalty**
- 20 days: **10% penalty**
- 15 days: **15% penalty**
- Instant: **20% penalty**

Penalties are routed to liquidity.

---

## Instant Unlock Safeguards

- Rolling window: **24 hours**
- Instant unlock cap: **20% of unlocked balance per window**
- Excess instant unlock attempts revert

---

## Fees

Claim fee:
- Minimum: **$2 USDC**
- Percentage: **0.5% of claim value (oracle-based, v1)**

Swap fees (Gateway):
- Entry (USDC → DSRX): **0.10%**
- Exit (DSRX → USDC): **0.80%**

---

## Liquidity

- Liquidity source: **Protocol fees + penalties**
- Liquidity pairing: **USDC / DSRX**
- Liquidity type: **Uniswap v3 full-range (v0)**
- Liquidity withdrawal: **Impossible**
- LP tokens: **Permanently locked**

---

## Governance & Control

- Fee governance: **Timelock-controlled**
- Timelock delay: **48–72 hours (finalized pre-deploy)**
- Timelock admin: **Multisig**
- Emergency controls: **None**

---

## Non-Goals (Explicit)

Distriba v0 does NOT include:
- Guaranteed returns
- Price floors
- Treasury intervention
- Buybacks
- LP migration
- Emission changes

---

## Parameter Change Policy

Only the following may change in v0:
- Activation fee (increase only, via timelock)
- Gateway pool fee (timelock recommended)

All other parameters are immutable.

---

## Status

v0 parameters are frozen upon deployment.

Future changes require a new protocol version.
