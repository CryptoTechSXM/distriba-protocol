# Design Decisions

This document records the reasoning behind key design decisions in the
Distriba protocol.

Its purpose is to preserve context, prevent design drift, and ensure that
future changes respect the original intent of the system.

---

## Why Distriba Does Not Promise Returns

The protocol explicitly avoids promising returns to:
- Reduce legal and regulatory risk
- Avoid unsustainable economic commitments
- Ensure outcomes are market-driven, not guaranteed

Distriba enforces rules, not results.

---

## Why Earning Is Time-Based

Time-based accrual was chosen to:
- Reward patience and participation
- Prevent instant extraction
- Align incentives with long-term system health

Immediate distribution mechanisms were rejected as fragile and easily abused.

---

## Why There Is a Lifetime Earning Cap

Finite earning caps were introduced to:
- Prevent infinite farming
- Bound total emissions
- Ensure fairness across participants

Caps limit **token quantity**, not value, preserving market dynamics.

---

## Why the Cap Is Approximately 1.5×

A moderate cap was selected to:
- Provide meaningful upside without requiring price appreciation
- Avoid excessive emission pressure
- Maintain liquidity survivability under stress

Lower caps felt unrewarding.
Higher caps increased systemic risk.

---

## Why Vesting Penalties Are Routed to Liquidity

Early unlock penalties are routed into protocol liquidity rather than burned or
captured by any party.

This decision:
- Strengthens liquidity depth
- Reduces slippage
- Improves exit safety
- Converts impatience into system resilience

Burning penalties was considered and rejected for v0 due to weaker liquidity effects.

---

## Why Liquidity Is Permanently Locked

Liquidity is locked forever to:
- Eliminate rug-pull risk
- Remove discretionary control
- Build long-term trust

No migration or withdrawal mechanism exists in v0.

This rigidity is intentional.

---

## Why There Is No Treasury or Buyback Mechanism

Treasury-controlled buybacks were rejected because they:
- Introduce discretionary control
- Create expectations of price defense
- Fail under sustained market pressure

Distriba allows price to be set purely by market forces.

---

## Why Instant Unlocks Are Allowed (With Penalties)

Instant access is allowed to:
- Respect user autonomy
- Avoid forced lock-in narratives

However, strict penalties and caps ensure:
- Short-term extraction is expensive
- Long-term participants are not harmed

---

## Why Governance Is Minimal

Governance was minimized to:
- Reduce attack surface
- Prevent parameter abuse
- Preserve predictability

Only limited parameters may change, and only through time delays.

---

## Why Beta Pricing Is Lower

Early pricing is lower to reflect:
- Higher volatility
- Thinner liquidity
- Greater uncertainty

As the system stabilizes, activation fees increase accordingly.

---

## Why Documentation Precedes Code Changes

Documentation was prioritized to:
- Freeze intent
- Align contributors
- Prevent accidental promise-making

Code implements decisions; it does not define them.

---

## Summary

Every major decision in Distriba favors:
- Durability over hype
- Predictability over discretion
- Fairness over guarantees

This document exists so that future changes respect these principles.
