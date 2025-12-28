# Testnet Findings — Distriba v0

This document records all findings discovered during testnet deployment
and testing of Distriba v0.

No changes may be made to protocol code or parameters without an entry
in this document.

---

## Entry Format

Each finding MUST include:

- **Date**
- **Component**
- **Description**
- **Severity** (Low / Medium / High / Critical)
- **Reproduction Steps**
- **Impact**
- **Decision**
- **Resolution (if any)**

---

## Findings

- Date: 2025-12-27
- Component: Testnet Environment
- Description: Arbitrum Sepolia ETH unavailable via public faucets
- Severity: Low
- Decision: Proceeded with local EVM testnet for v0 logic validation
- Resolution: Will deploy to Arbitrum Sepolia when infrastructure stabilizes

- Date: 2025-12-27
- Component: Repository Structure
- Description: Contracts directory was initially missing from GitHub
- Severity: Low
- Impact: None (no deployed contracts)
- Decision: Added contracts directory before any testnet deployment
- Resolution: Repo structure verified before deployment
