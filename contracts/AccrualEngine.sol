// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IFeeRouter {
    function onUSDCFeeReceived(uint256 amountUSDC) external;
}

/**
 * @title AccrualEngine (v0.1 - hardened, $50 start, guarded fee increases)
 * @notice Tracks miner licenses and accrues entitlement over time.
 *
 * v0 assumptions:
 * - 1 miner per wallet (single license at a time)
 * - Activation/Renewal fee starts at $50 USDC (50e6 with 6 decimals)
 * - License duration: 180 days
 *
 * SECURITY:
 * - vestingVault is wired ONCE by DeployFactory
 * - feeGovernor is wired ONCE by DeployFactory (later: set this to a timelock)
 * - activation fee increases are capped and rate-limited
 */
contract AccrualEngine {
    IERC20 public immutable usdc;
    IFeeRouter public immutable feeRouter;

    /// @notice DeployFactory that created this contract (allowed to do one-time wiring)
    address public immutable deployer;

    address public vestingVault;
    bool public vestingVaultLocked;

    /// @notice Fee governor (later: timelock). Set once by deployer.
    address public feeGovernor;
    bool public feeGovernorLocked;

    /// @notice Start at $50 (USDC has 6 decimals)
    uint256 public activationFeeUSDC = 50e6;

    uint256 public constant LICENSE_SECONDS = 180 days;

    // Guardrails for fee updates
    uint256 public constant FEE_UPDATE_COOLDOWN = 90 days;
    uint16  public constant MAX_FEE_STEP_BPS    = 2500; // 25%

    uint64 public lastFeeUpdate;

    // Placeholder entitlement accounting
    mapping(address => uint256) public entitlementWad;
    mapping(address => uint64) public licenseExpiry;

    event Activated(address indexed user, uint64 expiresAt, uint256 feeUSDC);
    event Renewed(address indexed user, uint64 expiresAt, uint256 feeUSDC);
    event VestingVaultSetOnce(address vestingVault);
    event FeeGovernorSetOnce(address feeGovernor);
    event ActivationFeeUpdated(uint256 oldFeeUSDC, uint256 newFeeUSDC);
    event EntitlementConsumed(address indexed user, uint256 amountWad);

    modifier onlyVestingVault() {
        require(msg.sender == vestingVault, "not vesting");
        _;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, "not deployer");
        _;
    }

    modifier onlyFeeGovernor() {
        require(msg.sender == feeGovernor, "not governor");
        _;
    }

    constructor(address usdc_, address feeRouter_) {
        require(usdc_ != address(0), "usdc=0");
        require(feeRouter_ != address(0), "feeRouter=0");
        usdc = IERC20(usdc_);
        feeRouter = IFeeRouter(feeRouter_);
        deployer = msg.sender;

        // Optional: allow first change immediately once governor is set
        lastFeeUpdate = uint64(block.timestamp);
    }

    /// @notice One-time wiring from DeployFactory
    function setVestingVaultOnce(address vestingVault_) external onlyDeployer {
        require(!vestingVaultLocked, "vv locked");
        require(vestingVault_ != address(0), "vv=0");
        vestingVault = vestingVault_;
        vestingVaultLocked = true;
        emit VestingVaultSetOnce(vestingVault_);
    }

    /// @notice One-time wiring for fee governor (later: set to timelock)
    function setFeeGovernorOnce(address feeGovernor_) external onlyDeployer {
        require(!feeGovernorLocked, "gov locked");
        require(feeGovernor_ != address(0), "gov=0");
        feeGovernor = feeGovernor_;
        feeGovernorLocked = true;
        emit FeeGovernorSetOnce(feeGovernor_);
    }

    /**
     * @notice Update activation fee with guardrails.
     * - Only feeGovernor (later: timelock)
     * - Cooldown between changes
     * - Max +25% per change (we can allow decreases later if you want)
     */
    function setActivationFeeUSDC(uint256 newFeeUSDC) external onlyFeeGovernor {
        require(newFeeUSDC > 0, "fee=0");
        require(block.timestamp >= uint256(lastFeeUpdate) + FEE_UPDATE_COOLDOWN, "cooldown");

        uint256 old = activationFeeUSDC;

        // Increase-only guard (matches your request: “options to increase like before”)
        require(newFeeUSDC >= old, "increase only");

        // Cap step size: new <= old * (1 + 25%)
        uint256 maxAllowed = (old * (10_000 + MAX_FEE_STEP_BPS)) / 10_000;
        require(newFeeUSDC <= maxAllowed, "step too big");

        activationFeeUSDC = newFeeUSDC;
        lastFeeUpdate = uint64(block.timestamp);

        emit ActivationFeeUpdated(old, newFeeUSDC);
    }

    function activate() external {
        require(licenseExpiry[msg.sender] < block.timestamp, "active");
        _collectFeeAndRoute();

        uint64 exp = uint64(block.timestamp + LICENSE_SECONDS);
        licenseExpiry[msg.sender] = exp;

        // Skeleton entitlement bump
        entitlementWad[msg.sender] += 1e18;

        emit Activated(msg.sender, exp, activationFeeUSDC);
    }

    function renew() external {
        require(licenseExpiry[msg.sender] >= block.timestamp, "not active");
        _collectFeeAndRoute();

        uint64 exp = uint64(licenseExpiry[msg.sender] + LICENSE_SECONDS);
        licenseExpiry[msg.sender] = exp;

        entitlementWad[msg.sender] += 1e18;

        emit Renewed(msg.sender, exp, activationFeeUSDC);
    }

    function _collectFeeAndRoute() internal {
        require(usdc.transferFrom(msg.sender, address(feeRouter), activationFeeUSDC), "fee xfer");
        feeRouter.onUSDCFeeReceived(activationFeeUSDC);
    }

    /// @notice Called only by VestingVault when user claims
    function consumeEntitlement(address user, uint256 amountWad) external onlyVestingVault {
        require(entitlementWad[user] >= amountWad, "entitlement");
        unchecked {
            entitlementWad[user] -= amountWad;
        }
        emit EntitlementConsumed(user, amountWad);
    }

    function entitlementOf(address user) external view returns (uint256) {
        return entitlementWad[user];
    }
}
