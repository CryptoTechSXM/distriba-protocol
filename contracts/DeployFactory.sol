// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LPPositionLocker.sol";
import "./FeeRouter.sol";
import "./AccrualEngine.sol";
import "./VestingVault.sol";
import "./DSRX.sol";
import "./Gateway.sol";
import "./FeeTimelock.sol";

/**
 * @title DeployFactory (v0)
 * @notice Simple deployer for Distriba v0 using `new` (NOT CREATE2).
 *
 * Why this exists:
 * - Avoids CREATE2 stack-too-deep issues in Remix
 * - Safer for novice deployment
 * - Perfect for Base Sepolia testnet validation
 *
 * IMPORTANT:
 * - You can reintroduce CREATE2 in v1+ after everything is stable.
 */
contract DeployFactory {
    /// @notice VestingVault resolves token address via factory.dsrx()
    address public dsrx;

    /// @notice Prevent accidental multiple deployments from the same factory instance
    bool public deployed;

    struct ExternalAddrs {
        address usdc;                    // MockUSDC on testnet
        address uniswapV3PositionManager;
        address uniswapV3SwapRouter;
        uint24  uniswapPoolFee;          // e.g. 3000
    }

    struct Params {
        uint256 activationFeeUSDC;       // 50e6 for $50 (6 decimals)
        address multisig;                // testnet admin wallet or Safe
        uint64  feeTimelockDelay;        // e.g. 48h = 172800
    }

    struct Deployed {
        address lpLocker;
        address feeRouter;
        address accrualEngine;
        address vestingVault;
        address dsrx;
        address gateway;
        address feeTimelock;
    }

    event DeployedAll(Deployed d);

    function deployAll(ExternalAddrs calldata x, Params calldata p) external returns (Deployed memory d) {
        require(!deployed, "already deployed");
        deployed = true;

        require(x.usdc != address(0), "usdc=0");
        require(x.uniswapV3PositionManager != address(0), "pm=0");
        require(x.uniswapV3SwapRouter != address(0), "swap=0");
        require(x.uniswapPoolFee != 0, "poolFee=0");

        require(p.activationFeeUSDC != 0, "actFee=0");
        require(p.multisig != address(0), "msig=0");
        require(p.feeTimelockDelay != 0, "delay=0");

        // 1) Locker
        LPPositionLocker locker = new LPPositionLocker(x.uniswapV3PositionManager);

        // 2) FeeRouter (set-once wiring later)
        FeeRouter router = new FeeRouter(x.usdc, x.uniswapV3PositionManager);

        // 3) AccrualEngine (wired to router)
        AccrualEngine accrual = new AccrualEngine(x.usdc, address(router));

        // 4) VestingVault (resolves DSRX via this factory)
        VestingVault vault = new VestingVault(x.usdc, address(accrual), address(router), address(this));

        // 5) DSRX token (controller = vault)
        DSRX token = new DSRX(address(vault));
        dsrx = address(token);

        // 6) Wire FeeRouter set-once addresses
        router.setLockerOnce(address(locker));
        router.setDSRXOnce(address(token));

        // 7) Lock VestingVault into AccrualEngine
        accrual.setVestingVaultOnce(address(vault));

        // 8) Set starting activation fee BEFORE handing control to timelock.
        // This requires AccrualEngine to allow this call at this stage (see note below).
        accrual.setActivationFeeUSDC(p.activationFeeUSDC);

        // 9) Timelock controls future fee updates
        FeeTimelock tl = new FeeTimelock(p.multisig, p.feeTimelockDelay, address(accrual));
        accrual.setFeeGovernorOnce(address(tl));

        // 10) Gateway
        Gateway gateway = new Gateway(x.usdc, address(token), address(router), x.uniswapV3SwapRouter);
        gateway.setPoolFee(x.uniswapPoolFee);

        // 11) Authorize callers to notify fees, then lock forever
        router.setAuthorizedCaller(address(accrual), true);
        router.setAuthorizedCaller(address(vault), true);
        router.setAuthorizedCaller(address(gateway), true);
        router.finalizeAuthorizedCallers();

        d = Deployed({
            lpLocker: address(locker),
            feeRouter: address(router),
            accrualEngine: address(accrual),
            vestingVault: address(vault),
            dsrx: address(token),
            gateway: address(gateway),
            feeTimelock: address(tl)
        });

        emit DeployedAll(d);
    }
}
