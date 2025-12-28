// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccrualEngineFee {
    function setActivationFeeUSDC(uint256 newFeeUSDC) external;
}

/**
 * @title FeeTimelock (v0)
 * @notice Minimal timelock that can ONLY raise the activation fee on AccrualEngine.
 *
 * - Controlled by a multisig (admin)
 * - Enforces a delay between schedule and execute
 * - Stores one pending fee change at a time (simple + safe for novices)
 *
 * Safety upgrades:
 * - Prevents overwriting an existing scheduled change
 * - Enforces a minimum fee (defaults to $50 USDC with 6 decimals)
 */
contract FeeTimelock {
    address public immutable admin;     // multisig (e.g., Gnosis Safe)
    uint64  public immutable delay;     // e.g. 7 days (604800)

    address public immutable accrualEngine;

    // Optional minimum fee floor (USDC has 6 decimals)
    uint256 public constant MIN_FEE_USDC = 50e6; // $50

    uint256 public pendingFeeUSDC;
    uint64  public eta;                 // earliest time the pending fee can be executed

    event FeeChangeScheduled(uint256 newFeeUSDC, uint64 eta);
    event FeeChangeExecuted(uint256 newFeeUSDC);
    event FeeChangeCancelled();

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor(address admin_, uint64 delay_, address accrualEngine_) {
        require(admin_ != address(0), "admin=0");
        require(delay_ > 0, "delay=0");
        require(accrualEngine_ != address(0), "accrual=0");

        admin = admin_;
        delay = delay_;
        accrualEngine = accrualEngine_;
    }

    /// @notice Schedule a fee increase (must wait delay before execute)
    function scheduleFee(uint256 newFeeUSDC) external onlyAdmin {
        require(pendingFeeUSDC == 0, "already scheduled");
        require(newFeeUSDC >= MIN_FEE_USDC, "min $50");
        pendingFeeUSDC = newFeeUSDC;
        eta = uint64(block.timestamp + delay);
        emit FeeChangeScheduled(newFeeUSDC, eta);
    }

    /// @notice Cancel a scheduled fee change
    function cancel() external onlyAdmin {
        pendingFeeUSDC = 0;
        eta = 0;
        emit FeeChangeCancelled();
    }

    /// @notice Execute after eta
    function execute() external onlyAdmin {
        uint256 fee = pendingFeeUSDC;
        require(fee != 0, "no pending");
        require(eta != 0 && block.timestamp >= eta, "too early");

        // Clear first (reentrancy-safe habit)
        pendingFeeUSDC = 0;
        eta = 0;

        IAccrualEngineFee(accrualEngine).setActivationFeeUSDC(fee);
        emit FeeChangeExecuted(fee);
    }
}
