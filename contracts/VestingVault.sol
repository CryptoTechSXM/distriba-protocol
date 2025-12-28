// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccrualEngine {
    function consumeEntitlement(address user, uint256 amountWad) external;
    function entitlementOf(address user) external view returns (uint256);
}

interface IFeeRouter {
    function onUSDCFeeReceived(uint256 amountUSDC) external;
    function onDSRXFeeReceived(uint256 amountDSRX) external;
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// ✅ This was missing in your version, but you use IDSRX(...) below.
interface IDSRX {
    function mint(address to, uint256 amount) external;
}

interface IDeployFactoryDSRX {
    function dsrx() external view returns (address);
}

/**
 * @title VestingVault (v0 skeleton)
 * @notice Converts time-earned entitlement into vested balances (vDSRX) and releases DSRX over time.
 *
 * v0 decisions baked in:
 * - default vest: 60 days
 * - accelerated unlock haircuts:
 *    Instant: 20%
 *    15 days: 15%
 *    20 days: 10%
 *    30 days: 5%
 *    60 days: 0%
 * - anti-whale cap applies to Instant unlock, baseline = current unlocked DSRX balance (placeholder)
 * - claim fee in USDC: max($2, 0.5% of claim value in USDC)  <-- placeholder; needs price oracle
 * - all fees route to FeeRouter for permanent LP injection
 *
 * NOTE: This is a skeleton. Production version needs:
 * - TWAP oracle integration
 * - reentrancy guard
 * - full access control
 * - tests for edge cases
 */
contract VestingVault {
    /*//////////////////////////////////////////////////////////////
                                CONFIG
    //////////////////////////////////////////////////////////////*/

    uint256 public constant DEFAULT_VEST_SECONDS = 60 days;

    // Haircuts in basis points (bps). 10_000 = 100%
    uint16 public constant HAIRCUT_INSTANT_BPS = 2000; // 20%
    uint16 public constant HAIRCUT_15D_BPS     = 1500; // 15%
    uint16 public constant HAIRCUT_20D_BPS     = 1000; // 10%
    uint16 public constant HAIRCUT_30D_BPS     =  500; // 5%
    uint16 public constant HAIRCUT_60D_BPS     =    0; // 0%

    // Anti-whale cap: instant unlock within 24h limited to unlockedBalance * capBps
    uint16 public constant INSTANT_CAP_BPS = 2000; // 20% per rolling window
    uint256 public constant CAP_WINDOW = 24 hours;

    // Claim fee minimum: $2 USDC (USDC has 6 decimals)
    uint256 public constant CLAIM_FEE_MIN_USDC = 2e6;

    // Claim fee percent: 0.5% (50 bps) of claim value (placeholder)
    uint16 public constant CLAIM_FEE_BPS = 50;

    IERC20 public immutable usdc;
    IAccrualEngine public immutable accrualEngine;
    IFeeRouter public immutable feeRouter;

    /// ✅ CREATE2-friendly: resolve DSRX via factory (no setters)
    address public immutable factory;

    /*//////////////////////////////////////////////////////////////
                               DATA MODEL
    //////////////////////////////////////////////////////////////*/

    enum UnlockTier {
        Default60d,  // 0% haircut, 60 days
        Days30,      // 5% haircut, 30 days
        Days20,      // 10% haircut, 20 days
        Days15,      // 15% haircut, 15 days
        Instant      // 20% haircut, immediate
    }

    struct VestingPosition {
        uint128 total;     // total vested (vDSRX units)
        uint128 claimed;   // amount already claimed as DSRX
        uint64  start;     // vest start timestamp
        uint64  end;       // vest end timestamp
    }

    // Each user can have multiple vesting positions for simplicity (claim creates one).
    mapping(address => VestingPosition[]) internal positions;

    // Track how much was instant-unlocked within the rolling window.
    struct InstantCap {
        uint64 windowStart;     // start timestamp of current window
        uint128 used;           // used amount within window (pre-haircut amount)
    }
    mapping(address => InstantCap) public instantCap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimedEntitlement(
        address indexed user,
        uint256 entitlementConsumed,
        uint256 vestedAmountNet,
        UnlockTier tier,
        uint256 feeUSDC
    );

    event Accelerated(
        address indexed user,
        uint256 amountVestedInput,
        UnlockTier tier,
        uint256 haircutAmount,
        uint256 feeValueInDSRX
    );

    event DSRXWithdrawn(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address usdc_, address accrualEngine_, address feeRouter_, address factory_) {
        require(usdc_ != address(0), "USDC=0");
        require(accrualEngine_ != address(0), "Accrual=0");
        require(feeRouter_ != address(0), "FeeRouter=0");
        require(factory_ != address(0), "Factory=0");

        usdc = IERC20(usdc_);
        accrualEngine = IAccrualEngine(accrualEngine_);
        feeRouter = IFeeRouter(feeRouter_);
        factory = factory_;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _dsrxAddr() internal view returns (address a) {
        a = IDeployFactoryDSRX(factory).dsrx();
        require(a != address(0), "DSRX not set");
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function getPositions(address user) external view returns (VestingPosition[] memory) {
        return positions[user];
    }

    /// @notice Returns total vDSRX not yet claimed (sum of (total-claimed))
    function vBalanceOf(address user) public view returns (uint256 vBal) {
        VestingPosition[] storage ps = positions[user];
        for (uint256 i = 0; i < ps.length; i++) {
            vBal += (uint256(ps[i].total) - uint256(ps[i].claimed));
        }
    }

    /// @notice Returns how much DSRX is currently claimable from all positions.
    function claimableDSRX(address user) public view returns (uint256 claimable) {
        VestingPosition[] storage ps = positions[user];
        uint64 nowTs = uint64(block.timestamp);

        for (uint256 i = 0; i < ps.length; i++) {
            claimable += _claimableFrom(ps[i], nowTs);
        }
    }

    function _claimableFrom(VestingPosition storage p, uint64 nowTs) internal view returns (uint256) {
        if (p.total == 0) return 0;

        if (nowTs <= p.start) return 0;
        if (nowTs >= p.end) {
            return uint256(p.total) - uint256(p.claimed);
        }

        // linear vesting
        uint256 elapsed = uint256(nowTs - p.start);
        uint256 duration = uint256(p.end - p.start);

        uint256 vested = (uint256(p.total) * elapsed) / duration;
        if (vested <= uint256(p.claimed)) return 0;

        return vested - uint256(p.claimed);
    }

    /*//////////////////////////////////////////////////////////////
                         CLAIM ENTITLEMENT → vDSRX
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Claim entitlement (earned in AccrualEngine) into a new vesting position.
     * @param entitlementAmountWad Amount of entitlement to consume (wad units).
     * @param tier Unlock tier (determines haircut and vesting duration).
     */
    function claimFromEntitlement(uint256 entitlementAmountWad, UnlockTier tier) external {
        require(entitlementAmountWad > 0, "amount=0");

        // 1) Consume entitlement from AccrualEngine
        // NOTE: AccrualEngine must restrict this call to VestingVault in production.
        accrualEngine.consumeEntitlement(msg.sender, entitlementAmountWad);

        // 2) Apply claim fee in USDC (placeholder)
        uint256 feeUSDC = _computeClaimFeeUSDC(entitlementAmountWad);

        // pull USDC from user and route to FeeRouter
        require(usdc.transferFrom(msg.sender, address(feeRouter), feeUSDC), "USDC transfer failed");
        feeRouter.onUSDCFeeReceived(feeUSDC);

        // 3) Apply tier haircut, create vesting position
        (uint256 net, uint256 haircut, uint64 duration) = _applyTier(entitlementAmountWad, tier);

        // Route haircut value to FeeRouter (in DSRX terms for now).
        if (haircut > 0) {
            feeRouter.onDSRXFeeReceived(haircut);
        }

        // 4) Store vesting position for net amount
        _createPosition(msg.sender, net, duration);

        emit ClaimedEntitlement(msg.sender, entitlementAmountWad, net, tier, feeUSDC);
    }

    function _createPosition(address user, uint256 amount, uint64 duration) internal {
        require(amount > 0, "net=0");
        uint64 nowTs = uint64(block.timestamp);
        uint64 end = uint64(uint256(nowTs) + uint256(duration));

        positions[user].push(
            VestingPosition({
                total: uint128(amount),
                claimed: 0,
                start: nowTs,
                end: end
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                            ACCELERATE UNLOCK
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Accelerate existing vesting by moving some unclaimed vDSRX into a new faster position.
     * @dev This skeleton simply takes from the "oldest positions" first.
     */
    function accelerateUnlock(uint256 vAmount, UnlockTier tier) external {
        require(vAmount > 0, "amount=0");
        require(tier != UnlockTier.Default60d, "already default");

        // Enforce instant cap if tier is Instant
        if (tier == UnlockTier.Instant) {
            _enforceInstantCap(msg.sender, vAmount);
        }

        // Move vAmount from existing positions into a new position with haircut+duration
        uint256 pulled = _pullVested(msg.sender, vAmount);
        require(pulled == vAmount, "insufficient v");

        (uint256 net, uint256 haircut, uint64 duration) = _applyTier(vAmount, tier);

        if (haircut > 0) {
            feeRouter.onDSRXFeeReceived(haircut);
        }

        if (tier == UnlockTier.Instant) {
            // Instant means "duration=0": mint immediately as claimable by making a zero-duration position
            _createPosition(msg.sender, net, 1); // 1 second vest to avoid divide-by-zero
        } else {
            _createPosition(msg.sender, net, duration);
        }

        emit Accelerated(msg.sender, vAmount, tier, haircut, haircut);
    }

    /// @notice Pulls unclaimed vDSRX from existing positions (oldest-first).
    function _pullVested(address user, uint256 amount) internal returns (uint256 pulled) {
        VestingPosition[] storage ps = positions[user];

        for (uint256 i = 0; i < ps.length && pulled < amount; i++) {
            uint256 available = uint256(ps[i].total) - uint256(ps[i].claimed);
            if (available == 0) continue;

            uint256 take = (amount - pulled);
            if (take > available) take = available;

            // Skeleton simplification: reduce by marking as claimed.
            ps[i].claimed += uint128(take);
            pulled += take;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW UNLOCKED DSRX
    //////////////////////////////////////////////////////////////*/

    function withdrawUnlocked() external returns (uint256 amountOut) {
        VestingPosition[] storage ps = positions[msg.sender];
        uint64 nowTs = uint64(block.timestamp);

        for (uint256 i = 0; i < ps.length; i++) {
            uint256 c = _claimableFrom(ps[i], nowTs);
            if (c == 0) continue;

            ps[i].claimed += uint128(c);
            amountOut += c;
        }

        require(amountOut > 0, "nothing");

        // Mint liquid DSRX to user (resolved via factory)
        IDSRX(_dsrxAddr()).mint(msg.sender, amountOut);

        emit DSRXWithdrawn(msg.sender, amountOut);
    }

    /*//////////////////////////////////////////////////////////////
                          INSTANT CAP LOGIC
    //////////////////////////////////////////////////////////////*/

    function _enforceInstantCap(address user, uint256 requested) internal {
        // Placeholder baseline:
        // In production, this should be DSRX.balanceOf(user).
        // For now we cap relative to vBalanceOf(user) as a temporary approximation.
        uint256 baseline = vBalanceOf(user);

        uint256 maxPerWindow = (baseline * INSTANT_CAP_BPS) / 10_000;

        InstantCap storage cap = instantCap[user];
        uint64 nowTs = uint64(block.timestamp);

        if (cap.windowStart == 0 || nowTs > cap.windowStart + CAP_WINDOW) {
            cap.windowStart = nowTs;
            cap.used = 0;
        }

        require(uint256(cap.used) + requested <= maxPerWindow, "instant cap");
        cap.used += uint128(requested);
    }

    /*//////////////////////////////////////////////////////////////
                        TIER / FEE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    function _applyTier(uint256 amount, UnlockTier tier)
        internal
        pure
        returns (uint256 net, uint256 haircut, uint64 duration)
    {
        uint16 bps;
        if (tier == UnlockTier.Instant) {
            bps = HAIRCUT_INSTANT_BPS;
            duration = 0;
        } else if (tier == UnlockTier.Days15) {
            bps = HAIRCUT_15D_BPS;
            duration = 15 days;
        } else if (tier == UnlockTier.Days20) {
            bps = HAIRCUT_20D_BPS;
            duration = 20 days;
        } else if (tier == UnlockTier.Days30) {
            bps = HAIRCUT_30D_BPS;
            duration = 30 days;
        } else {
            bps = HAIRCUT_60D_BPS;
            duration = uint64(DEFAULT_VEST_SECONDS);
        }

        haircut = (amount * bps) / 10_000;
        net = amount - haircut;
    }

    function _computeClaimFeeUSDC(uint256 entitlementAmountWad) internal pure returns (uint256) {
        // Placeholder: claim fee requires DSRX/USDC price oracle.
        // For now, we approximate by applying min fee only.
        entitlementAmountWad; // silence warning
        return CLAIM_FEE_MIN_USDC;
    }
}
