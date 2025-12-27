# Distriba Economic Model

This document describes the economic design of the Distriba protocol,
including incentives, constraints, and behavior under stress.

Distriba is designed to survive adverse conditions without requiring
guaranteed returns, treasury intervention, or discretionary control.

---

## Core Principles

The Distriba economic model is built on five principles:

1. Finite emissions
2. Time-based access
3. Penalties for impatience
4. Permanent liquidity
5. No guaranteed outcomes

All incentives and constraints follow from these principles.

---

## Activation Fees

Participants activate a time-limited license by paying an activation fee
in USDC.

The activation fee:
- Is not a purchase of tokens
- Does not guarantee value recovery
- Is routed into protocol mechanisms that strengthen liquidity

Activation fees may increase over time through governed processes.

---

## Entitlement Accrual

Each license accrues entitlement gradually over its active duration.

Entitlement:
- Represents the right to receive DSRX under protocol rules
- Accrues linearly over time
- Cannot exceed a predefined lifetime cap

Entitlement has no intrinsic dollar value until converted into tokens.

---

## Lifetime Earning Cap

Each license has a finite lifetime earning capacity expressed in
token entitlement.

The cap exists to:
- Prevent infinite farming
- Bound emissions
- Protect liquidity

The cap limits **token quantity**, not dollar value.

Depending on market conditions, realized value may exceed, match,
or fall below the activation cost.

---

## Vesting Mechanics

When entitlement is claimed, users choose a vesting schedule.

- Default vesting releases tokens gradually with no penalty
- Accelerated vesting reduces total tokens received
- Instant access carries the highest penalty

Vesting penalties are recycled into protocol liquidity.

---

## Liquidity Formation

Protocol fees and penalties are routed into liquidity as follows:

- Fees are paired with DSRX and USDC
- Liquidity positions are created on decentralized exchanges
- Liquidity positions are permanently locked

There is no mechanism for liquidity withdrawal by founders or users.

---

## Why Liquidity Does Not Equal Total Fees

Distriba does not require liquidity to equal total activation fees.

Reasons:
- Emissions are capped
- Not all participants exit simultaneously
- Vesting delays exits
- Penalties and exit fees grow liquidity during stress

Liquidity is designed to absorb **realized, capped exits over time**,
not worst-case theoretical extraction.

---

## Stress Scenario: Price Decline

In a scenario where token price declines significantly:

- Realized value per license decreases
- Liquidity absorbs exits gradually
- Penalties and exit fees increase liquidity
- The system continues operating without insolvency

There is no price defense mechanism.

---

## Stress Scenario: Coordinated Exits

In a coordinated exit attempt:

- Instant unlock limits restrict extraction rate
- Vesting penalties reduce extracted value
- Exit fees route value back into liquidity
- Liquidity absorbs pressure incrementally

The protocol converts extractive behavior into system strength.

---

## Anti-Extraction Design

Distriba prevents common failure modes through:

- Finite earning caps
- Time-based vesting
- Unlock penalties
- Exit fees
- Permanently locked liquidity

These mechanisms ensure that short-term extraction
comes at the expense of the extractor.

---

## No Return Guarantees

Distriba does not promise:
- Profit
- Yield
- Break-even outcomes

All returns depend on:
- Market price
- Liquidity depth
- User timing
- Vesting choices

The protocol enforces rules, not outcomes.

---

## Summary

The Distriba economic model:

- Aligns incentives over time
- Rewards patience
- Penalizes impatience
- Grows liquidity through usage
- Survives adverse conditions without intervention

This design prioritizes durability, transparency, and fairness
over short-term appeal.
