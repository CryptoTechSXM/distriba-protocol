# Distriba v0 Testnet Plan

This document defines the scope, objectives, and methodology for
testing Distriba v0 on testnet.

The goal is not feature completeness.
The goal is to eliminate catastrophic failure modes.

---

## Testnet Objectives

Testnet must validate that:

1. Funds cannot be stolen
2. Liquidity cannot be removed
3. Emissions are bounded
4. Users cannot extract more than allowed
5. Governance delays function correctly

Testnet is NOT used to optimize UX or pricing.

---

## In-Scope Tests

### 1. Deployment Integrity

- Deploy all contracts via factory
- Verify all addresses are non-zero
- Verify no second deployment is possible
- Confirm factory wiring (DSRX resolution works)

Expected outcome:
- Single deterministic deployment
- No mutable critical wiring

---

### 2. Activation & Licensing

Test cases:
- Activate miner with correct USDC fee
- Reject activation with insufficient USDC
- Reject double activation
- Renew license correctly extends expiry

Expected outcome:
- One active license per wallet
- Fees route to FeeRouter
- License expiry enforced

---

### 3. Entitlement Accrual

Test cases:
- Entitlement accrues linearly over time
- No accrual after license expiry
- No accrual without activation
- Entitlement cannot exceed lifetime cap

Expected outcome:
- Time-based entitlement only
- No infinite accrual

---

### 4. Vesting Behavior

Test cases:
- Default 60-day vest produces full amount
- Accelerated vest applies correct penalty
- Instant unlock enforces haircut
- Multiple vesting positions behave correctly

Expected outcome:
- Penalties applied exactly
- Net tokens correct

---

### 5. Instant Unlock Safeguards

Test cases:
- Instant unlock below cap succeeds
- Instant unlock above cap reverts
- Cap resets after window passes

Expected outcome:
- Rate-limited extraction
- No bypass possible

---

### 6. Liquidity Formation

Test cases:
- Fees arrive at FeeRouter
- LP position is minted
- LP NFT is transferred to locker
- Locker permanently holds NFT

Expected outcome:
- LP cannot be withdrawn
- Liquidity grows over time

---

### 7. Gateway Swaps

Test cases:
- USDC → DSRX swap applies entry fee
- DSRX → USDC swap applies exit fee
- Fees route to FeeRouter
- Slippage limits respected

Expected outcome:
- Correct asymmetric fees
- No free round-trips

---

### 8. Governance & Timelock

Test cases:
- Schedule activation fee increase
- Reject early execution
- Execute after delay
- Cancel scheduled change

Expected outcome:
- No instant parameter changes
- Multisig-controlled governance only

---

## Explicitly Out of Scope

The following are NOT tested in v0 testnet:

- Price appreciation
- Profitability
- APY modeling
- Frontend UX polish
- Oracle accuracy
- High-volume stress tests

These are intentionally excluded.

---

## Failure Criteria (Hard Stops)

Testnet fails if ANY of the following occur:

- Liquidity can be withdrawn
- A user extracts more than their cap
- Fees can be bypassed
- Governance delay can be skipped
- Tokens can be minted arbitrarily

Any failure here blocks mainnet.

---

## Documentation Policy

Every discovered issue must be recorded in:
- `notes/testnet-findings.md`

Each entry must include:
- Description
- Reproduction steps
- Impact assessment
- Resolution (or decision not to fix)

No undocumented fixes are allowed.

---

## Exit Criteria

Testnet concludes when:
- All in-scope tests pass
- No critical or high-severity issues remain
- v0 parameters remain unchanged

Only then may mainnet deployment proceed.
