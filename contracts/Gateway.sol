// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IFeeRouter {
    function onUSDCFeeReceived(uint256 amountUSDC) external;
}

/**
 * @notice Swap router placeholder. In production we will use Uniswap v3 SwapRouter.
 * This skeleton does NOT implement real Uniswap params structs; it shows where swaps go.
 */
interface ISwapRouterLike {
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMin
    ) external returns (uint256 amountOut);
}

/**
 * @title Gateway (v0 skeleton)
 * @notice Single entry point for USDC ↔ DSRX conversions with asymmetric fees.
 *
 * v0 fees:
 * - Entry (USDC→DSRX): 0.10% (10 bps)
 * - Exit  (DSRX→USDC): 0.80% (80 bps)
 *
 * All fees route to FeeRouter for permanent LP injection.
 */
contract Gateway {
    IERC20 public immutable usdc;
    IERC20 public immutable dsrx;

    IFeeRouter public immutable feeRouter;
    ISwapRouterLike public immutable swapRouter;

    /// @notice Deployer (DeployFactory) that created this Gateway
    address public immutable deployer;

    // Uniswap v3 pool fee tier (example: 3000 = 0.3%)
    uint24 public poolFee = 3000;

    // Fees in basis points
    uint16 public constant ENTRY_FEE_BPS = 10;  // 0.10%
    uint16 public constant EXIT_FEE_BPS  = 80;  // 0.80%

    event Converted(
        address indexed user,
        bool usdcToDsrx,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeUSDC
    );

    event PoolFeeUpdated(uint24 newFee);

    modifier onlyDeployer() {
        require(msg.sender == deployer, "not deployer");
        _;
    }

    constructor(address usdc_, address dsrx_, address feeRouter_, address swapRouter_) {
        require(usdc_ != address(0), "usdc=0");
        require(dsrx_ != address(0), "dsrx=0");
        require(feeRouter_ != address(0), "feeRouter=0");
        require(swapRouter_ != address(0), "swapRouter=0");

        usdc = IERC20(usdc_);
        dsrx = IERC20(dsrx_);
        feeRouter = IFeeRouter(feeRouter_);
        swapRouter = ISwapRouterLike(swapRouter_);
        deployer = msg.sender;
    }

    /// @notice Convert USDC → DSRX (entry fee charged in USDC)
    function convertUsdcToDsrx(uint256 amountInUSDC, uint256 minOutDSRX) external returns (uint256 outDSRX) {
        require(amountInUSDC > 0, "amount=0");

        // Pull USDC from user
        require(usdc.transferFrom(msg.sender, address(this), amountInUSDC), "transferFrom");

        // Fee in USDC
        uint256 feeUSDC = (amountInUSDC * ENTRY_FEE_BPS) / 10_000;
        uint256 swapAmount = amountInUSDC - feeUSDC;

        // Route fee to FeeRouter
        if (feeUSDC > 0) {
            require(usdc.transfer(address(feeRouter), feeUSDC), "fee xfer");
            feeRouter.onUSDCFeeReceived(feeUSDC);
        }

        // Swap remaining USDC to DSRX (placeholder router call)
        usdc.approve(address(swapRouter), swapAmount);

        outDSRX = swapRouter.swapExactInputSingle(
            address(usdc),
            address(dsrx),
            poolFee,
            msg.sender,
            swapAmount,
            minOutDSRX
        );

        emit Converted(msg.sender, true, amountInUSDC, outDSRX, feeUSDC);
    }

    /// @notice Convert DSRX → USDC (exit fee charged in USDC after swap)
    function convertDsrxToUsdc(uint256 amountInDSRX, uint256 minOutUSDC) external returns (uint256 outUSDC) {
        require(amountInDSRX > 0, "amount=0");

        // Pull DSRX from user
        require(dsrx.transferFrom(msg.sender, address(this), amountInDSRX), "transferFrom");

        // Swap DSRX to USDC first (placeholder router call)
        dsrx.approve(address(swapRouter), amountInDSRX);

        uint256 grossUSDC = swapRouter.swapExactInputSingle(
            address(dsrx),
            address(usdc),
            poolFee,
            address(this),
            amountInDSRX,
            0
        );

        // Exit fee charged in USDC
        uint256 feeUSDC = (grossUSDC * EXIT_FEE_BPS) / 10_000;
        uint256 netUSDC = grossUSDC - feeUSDC;

        require(netUSDC >= minOutUSDC, "slippage");

        // Route fee to FeeRouter
        if (feeUSDC > 0) {
            require(usdc.transfer(address(feeRouter), feeUSDC), "fee xfer");
            feeRouter.onUSDCFeeReceived(feeUSDC);
        }

        // Send user net USDC
        require(usdc.transfer(msg.sender, netUSDC), "usdc xfer");

        emit Converted(msg.sender, false, amountInDSRX, netUSDC, feeUSDC);
        return netUSDC;
    }

    /// @notice Pool params setter (skeleton only). Production should be immutable or timelocked.
    function setPoolFee(uint24 newFee) external onlyDeployer {
        require(newFee != 0, "fee=0");
        poolFee = newFee;
        emit PoolFeeUpdated(newFee);
    }
}
