// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface INonfungiblePositionManager {
    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient,
        uint256 deadline
    ) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/**
 * @title FeeRouter (v0.1 - set-once wiring, deployer-gated)
 * @notice Receives protocol fees and converts them into permanent Uniswap v3 liquidity.
 *
 * Security upgrade:
 * - All set-once wiring functions are restricted to the deployer (DeployFactory),
 *   preventing anyone from front-running wiring on deployment.
 *
 * Key idea:
 * - Constructor sets stable dependencies + deployer.
 * - dsrx + locker are wired ONCE by DeployFactory, then frozen forever.
 * - authorized callers are wired ONCE by DeployFactory, then frozen forever.
 */
contract FeeRouter {
    IERC20 public immutable usdc;
    INonfungiblePositionManager public immutable positionManager;

    /// @notice The only address allowed to perform one-time wiring.
    /// In our flow, this is the DeployFactory that created this FeeRouter.
    address public immutable deployer;

    // Set-once wired addresses
    address public dsrx;   // ERC20 token address
    address public locker; // LPPositionLocker address

    // Full-range for v0
    uint24 public poolFee = 3000; // default 0.3%
    int24 public constant MIN_TICK = -887220;
    int24 public constant MAX_TICK =  887220;

    // Who may notify fees (prevents grief calls)
    mapping(address => bool) public isAuthorizedCaller;

    // Set-once locks
    bool public dsrxLocked;
    bool public lockerLocked;
    bool public authLocked;

    event USDCFeeReceived(address indexed from, uint256 amountUSDC);
    event DSRXFeeReceived(address indexed from, uint256 amountDSRX);
    event LPAdded(uint256 amountUSDC, uint256 amountDSRX, uint256 tokenId);

    event DSRXSetOnce(address dsrx);
    event LockerSetOnce(address locker);
    event AuthorizedCallerSet(address caller, bool allowed);
    event AuthorizedLockFinalized();

    modifier onlyAuthorized() {
        require(isAuthorizedCaller[msg.sender], "not authorized");
        _;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, "not deployer");
        _;
    }

    constructor(address usdc_, address positionManager_) {
        require(usdc_ != address(0), "usdc=0");
        require(positionManager_ != address(0), "pm=0");
        usdc = IERC20(usdc_);
        positionManager = INonfungiblePositionManager(positionManager_);
        deployer = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                        SET-ONCE WIRING (DEPLOYER ONLY)
    //////////////////////////////////////////////////////////////*/

    /// @notice Wire DSRX once (called by DeployFactory right after DSRX deploy).
    function setDSRXOnce(address dsrx_) external onlyDeployer {
        require(!dsrxLocked, "dsrx locked");
        require(dsrx_ != address(0), "dsrx=0");
        dsrx = dsrx_;
        dsrxLocked = true;
        emit DSRXSetOnce(dsrx_);
    }

    /// @notice Wire locker once (called by DeployFactory right after locker deploy).
    function setLockerOnce(address locker_) external onlyDeployer {
        require(!lockerLocked, "locker locked");
        require(locker_ != address(0), "locker=0");
        locker = locker_;
        lockerLocked = true;
        emit LockerSetOnce(locker_);
    }

    /// @notice Set authorized callers (called by DeployFactory), then lock forever.
    function setAuthorizedCaller(address caller, bool allowed) external onlyDeployer {
        require(!authLocked, "auth locked");
        require(caller != address(0), "caller=0");
        isAuthorizedCaller[caller] = allowed;
        emit AuthorizedCallerSet(caller, allowed);
    }

    function finalizeAuthorizedCallers() external onlyDeployer {
        require(!authLocked, "auth locked");
        authLocked = true;
        emit AuthorizedLockFinalized();
    }

    /*//////////////////////////////////////////////////////////////
                        FEE ENTRYPOINTS
    //////////////////////////////////////////////////////////////*/

    function onUSDCFeeReceived(uint256 amountUSDC) external onlyAuthorized {
        emit USDCFeeReceived(msg.sender, amountUSDC);
        _tryAddLiquidity();
    }

    function onDSRXFeeReceived(uint256 amountDSRX) external onlyAuthorized {
        emit DSRXFeeReceived(msg.sender, amountDSRX);
        _tryAddLiquidity();
    }

    /*//////////////////////////////////////////////////////////////
                        LP BUILD LOGIC (PLACEHOLDER)
    //////////////////////////////////////////////////////////////*/

    function _tryAddLiquidity() internal {
        // Require wiring completed
        if (!dsrxLocked || !lockerLocked) return;

        uint256 usdcBal = usdc.balanceOf(address(this));
        uint256 dsrxBal = IERC20(dsrx).balanceOf(address(this));

        // For v0.1 skeleton: only add liquidity if both tokens present.
        // Production: do swaps so both sides exist.
        if (usdcBal == 0 || dsrxBal == 0) return;

        // Approve position manager
        usdc.approve(address(positionManager), usdcBal);
        IERC20(dsrx).approve(address(positionManager), dsrxBal);

        // NOTE: token0/token1 ordering matters in Uniswap v3.
        // For skeleton simplicity we pass (usdc, dsrx) and will correct ordering later.
        (uint256 tokenId,, uint256 amount0Used, uint256 amount1Used) =
            positionManager.mint(
                address(usdc),
                dsrx,
                poolFee,
                MIN_TICK,
                MAX_TICK,
                usdcBal,
                dsrxBal,
                0,
                0,
                address(this),
                block.timestamp
            );

        // Send LP NFT to locker (locker must implement onERC721Received)
        positionManager.safeTransferFrom(address(this), locker, tokenId);

        emit LPAdded(amount0Used, amount1Used, tokenId);
    }
}
