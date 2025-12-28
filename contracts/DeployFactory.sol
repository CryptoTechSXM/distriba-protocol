// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AccrualEngine.sol";
import "./LPPositionLocker.sol";
import "./VestingVault.sol";
import "./DSRX.sol";
import "./FeeRouter.sol";
import "./Gateway.sol";

/**
 * @title DeployFactoryCreate2
 * @notice Deterministically deploys Distriba v0 contracts using CREATE2.
 *
 * Notes:
 * - Uses fixed salts.
 * - Emits deployed addresses.
 * - Designed to avoid "set once" initializer hooks.
 *
 * REQUIREMENT:
 * - VestingVault must be able to resolve DSRX address without a setter.
 *   Recommended: VestingVault stores factory address immutable, and reads DSRX from factory.
 */
contract DeployFactoryCreate2 {
    // Fixed salts for deterministic addresses
    bytes32 internal constant SALT_ACCRUAL = keccak256("DISTRIBA:ACCRUAL:V0");
    bytes32 internal constant SALT_LOCKER  = keccak256("DISTRIBA:LOCKER:V0");
    bytes32 internal constant SALT_VAULT   = keccak256("DISTRIBA:VAULT:V0");
    bytes32 internal constant SALT_DSRX    = keccak256("DISTRIBA:DSRX:V0");
    bytes32 internal constant SALT_ROUTER  = keccak256("DISTRIBA:FEEROUTER:V0");
    bytes32 internal constant SALT_GATEWAY = keccak256("DISTRIBA:GATEWAY:V0");

    struct ExternalAddrs {
        address usdc;
        address uniswapV3PositionManager;
        address uniswapV3SwapRouter;
        uint24  uniswapPoolFee; // e.g. 3000
    }

    struct Params {
        uint256 activationFeeUSDC; // 15e6 for $15 if USDC has 6 decimals
    }

    struct Deployed {
        address accrualEngine;
        address lpLocker;
        address vestingVault;
        address dsrx;
        address feeRouter;
        address gateway;
    }

    // Expose dsrx address for VestingVault to read (no setter)
    address public dsrx;

    event Predicted(Deployed predicted);
    event DeployedAll(Deployed deployed);

    /*//////////////////////////////////////////////////////////////
                            CREATE2 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _computeCreate2(bytes32 salt, bytes32 initCodeHash) internal view returns (address) {
        bytes32 h = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initCodeHash));
        return address(uint160(uint256(h)));
    }

    function _deployCreate2(bytes32 salt, bytes memory initCode) internal returns (address addr) {
        assembly {
            addr := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        require(addr != address(0), "CREATE2 fail");
    }

    /*//////////////////////////////////////////////////////////////
                            ADDRESS PREDICTION
    //////////////////////////////////////////////////////////////*/

    function predictAll(ExternalAddrs calldata x, Params calldata p) external view returns (Deployed memory out) {
        // Predict each init code hash with final constructor args.

        bytes32 accrualHash = keccak256(
            abi.encodePacked(type(AccrualEngine).creationCode, abi.encode(x.usdc, address(0) /*feeRouter placeholder - predicted below*/))
        );
        bytes32 lockerHash = keccak256(
            abi.encodePacked(type(LPPositionLocker).creationCode, abi.encode(x.uniswapV3PositionManager))
        );

        // We must predict FeeRouter address before AccrualEngine init args are final (because AccrualEngine takes feeRouter).
        // So we predict in a stable order:
        //
        // locker -> vault -> dsrx -> feeRouter -> accrual -> gateway
        //
        // Vault is deployed without dsrx arg (it reads factory.dsrx()).

        bytes32 vaultHash = keccak256(
            abi.encodePacked(type(VestingVault).creationCode, abi.encode(x.usdc, address(0) /*accrual predicted later*/, address(0) /*feeRouter predicted later*/, address(this) /*factory*/))
        );
        address vaultAddr = _computeCreate2(SALT_VAULT, vaultHash);

        bytes32 dsrxHash = keccak256(
            abi.encodePacked(type(DSRX).creationCode, abi.encode(vaultAddr))
        );
        address dsrxAddr = _computeCreate2(SALT_DSRX, dsrxHash);

        address lockerAddr = _computeCreate2(SALT_LOCKER, lockerHash);

        bytes32 feeRouterHash = keccak256(
            abi.encodePacked(type(FeeRouter).creationCode, abi.encode(x.usdc, dsrxAddr, x.uniswapV3PositionManager, lockerAddr))
        );
        address feeRouterAddr = _computeCreate2(SALT_ROUTER, feeRouterHash);

        // Now we can predict AccrualEngine with final feeRouter
        accrualHash = keccak256(
            abi.encodePacked(type(AccrualEngine).creationCode, abi.encode(x.usdc, feeRouterAddr))
        );
        address accrualAddr = _computeCreate2(SALT_ACCRUAL, accrualHash);

        // Recompute vault hash with final accrual + feeRouter
        vaultHash = keccak256(
            abi.encodePacked(type(VestingVault).creationCode, abi.encode(x.usdc, accrualAddr, feeRouterAddr, address(this)))
        );
        vaultAddr = _computeCreate2(SALT_VAULT, vaultHash);

        // dsrx controller must match final vaultAddr
        dsrxHash = keccak256(
            abi.encodePacked(type(DSRX).creationCode, abi.encode(vaultAddr))
        );
        dsrxAddr = _computeCreate2(SALT_DSRX, dsrxHash);

        // gateway
        bytes32 gatewayHash = keccak256(
            abi.encodePacked(type(Gateway).creationCode, abi.encode(x.usdc, dsrxAddr, feeRouterAddr, x.uniswapV3SwapRouter))
        );
        address gatewayAddr = _computeCreate2(SALT_GATEWAY, gatewayHash);

        out = Deployed({
            accrualEngine: accrualAddr,
            lpLocker: lockerAddr,
            vestingVault: vaultAddr,
            dsrx: dsrxAddr,
            feeRouter: feeRouterAddr,
            gateway: gatewayAddr
        });
    }

    /*//////////////////////////////////////////////////////////////
                              DEPLOY ALL
    //////////////////////////////////////////////////////////////*/

    function deployAll(ExternalAddrs calldata x, Params calldata p) external returns (Deployed memory out) {
        require(x.usdc != address(0), "usdc=0");
        require(x.uniswapV3PositionManager != address(0), "pm=0");
        require(x.uniswapV3SwapRouter != address(0), "swap=0");
        require(x.uniswapPoolFee != 0, "poolFee=0");

        // Predict to get final intended addresses
        out = this.predictAll(x, p);
        emit Predicted(out);

        // 1) Deploy Locker (no circular deps)
        _deployCreate2(
            SALT_LOCKER,
            abi.encodePacked(type(LPPositionLocker).creationCode, abi.encode(x.uniswapV3PositionManager))
        );

        // 2) Deploy FeeRouter (needs dsrx + locker)
        _deployCreate2(
            SALT_ROUTER,
            abi.encodePacked(type(FeeRouter).creationCode, abi.encode(x.usdc, out.dsrx, x.uniswapV3PositionManager, out.lpLocker))
        );

        // 3) Deploy AccrualEngine (needs feeRouter)
        address accrualAddr = _deployCreate2(
            SALT_ACCRUAL,
            abi.encodePacked(type(AccrualEngine).creationCode, abi.encode(x.usdc, out.feeRouter))
        );

        // Set activation fee (note: your AccrualEngine setter must be timelock-restricted later)
        AccrualEngine(accrualAddr).setActivationFeeUSDC(p.activationFeeUSDC);

        // 4) Deploy VestingVault (needs accrual + feeRouter + factory)
        _deployCreate2(
            SALT_VAULT,
            abi.encodePacked(type(VestingVault).creationCode, abi.encode(x.usdc, out.accrualEngine, out.feeRouter, address(this)))
        );

        // 5) Deploy DSRX with controller = Vault
        address dsrxAddr = _deployCreate2(
            SALT_DSRX,
            abi.encodePacked(type(DSRX).creationCode, abi.encode(out.vestingVault))
        );
        dsrx = dsrxAddr; // Expose for VestingVault reads

        // 6) Deploy Gateway (needs swapRouter)
        address gatewayAddr = _deployCreate2(
            SALT_GATEWAY,
            abi.encodePacked(type(Gateway).creationCode, abi.encode(x.usdc, out.dsrx, out.feeRouter, x.uniswapV3SwapRouter))
        );
        Gateway(gatewayAddr).setPoolFee(x.uniswapPoolFee);

        emit DeployedAll(out);
    }
}
