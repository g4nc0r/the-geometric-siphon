// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

// Minimal Uniswap V3 / Slipstream interfaces
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        uint160 sqrtPriceX96;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

interface IUniswapV3Pool {
    /// @dev Aerodrome Slipstream's slot0 has a different field layout from Uniswap V3.
    ///      We only need sqrtPriceX96 and tick; Solidity's ABI decoder reads exactly the
    ///      declared return bytes from the response and ignores the rest, so a
    ///      narrowed signature works against any pool whose first two slot0 fields
    ///      are (uint160 sqrtPriceX96, int24 tick) — true for both Uniswap V3 and
    ///      Slipstream.
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick);

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, int24 tickSpacing) external view returns (address pool);
}

/// @title GeometricResidualProof
/// @notice Proves that geometric residual is a mathematical property of CL, not an artifact
contract GeometricResidualProof is Test {
    // Base mainnet addresses
    address constant NFPM = 0x827922686190790b37229fd06084350E74485b72;
    address constant FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Rich wallet on Base for funding
    address constant WHALE = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A;

    INonfungiblePositionManager nfpm;
    IUniswapV3Pool pool;
    IUniswapV3Factory factory;
    IERC20 weth;
    IERC20 usdc;

    uint256 position1;
    uint256 position2;

    // Price oracle (simplified - using fixed price for USD conversion)
    uint256 constant ETH_PRICE_USD = 2500e6; // $2500 USDC per WETH

    function setUp() public {
        // Fork Base mainnet
        vm.createSelectFork("base");

        nfpm = INonfungiblePositionManager(NFPM);
        factory = IUniswapV3Factory(FACTORY);
        weth = IERC20(WETH);
        usdc = IERC20(USDC);

        // Get WETH/USDC pool with tickSpacing=100
        pool = IUniswapV3Pool(factory.getPool(WETH, USDC, 100));
        require(address(pool) != address(0), "Pool not found");

        console.log("Pool address:");
        console.log(address(pool));

        // Fund this contract using deal
        deal(WETH, address(this), 10 ether);
        deal(USDC, address(this), 25000e6);

        // Approve NFPM
        weth.approve(NFPM, type(uint256).max);
        usdc.approve(NFPM, type(uint256).max);

        console.log("Setup complete");
    }

    /// @notice Stage 1: Prove range change creates geometric residual
    function test_rangeChangeCreatesResidual() public {
        console.log("Test function started");
        (, int24 currentTick) = pool.slot0();
        console.log("Got slot0");

        // Create position 1: narrow range around current price
        int24 tickSpacing = 100;
        int24 tickLower1 = _nearestTick(currentTick - 500, tickSpacing);
        int24 tickUpper1 = _nearestTick(currentTick + 500, tickSpacing);

        console.log("=== Creating Position 1 ===");
        position1 = _mintPosition(tickLower1, tickUpper1, 1 ether, 2500e6);

        // Move price via swap
        console.log("=== Moving Price ===");
        _swapUSDCForWETH(1000e6);

        (, currentTick) = pool.slot0();
        console.log("New tick:");
        console.log(uint256(int256(currentTick)));

        // Measure balances before rebalance
        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));

        // Rebalance position 1: withdraw from old range, mint into new range (wider)
        console.log("=== Rebalancing Position 1 ===");
        int24 tickLower2 = _nearestTick(currentTick - 1000, tickSpacing);
        int24 tickUpper2 = _nearestTick(currentTick + 1000, tickSpacing);

        (uint256 amount0, uint256 amount1) = _withdrawPosition(position1);
        position1 = _mintPosition(tickLower2, tickUpper2, amount0, amount1);

        // Measure residual
        uint256 wethAfter = weth.balanceOf(address(this));
        uint256 usdcAfter = usdc.balanceOf(address(this));

        uint256 wethResidual = wethAfter - wethBefore;
        uint256 usdcResidual = usdcAfter - usdcBefore;

        console.log("=== RESIDUAL CREATED ===");
        console.log("WETH residual:");
        console.log(wethResidual);
        console.log("USDC residual:");
        console.log(usdcResidual);

        uint256 residualUSD = (wethResidual * ETH_PRICE_USD) / 1e18 + usdcResidual;
        console.log("Residual USD value (6 decimals):");
        console.log(residualUSD);

        // Assert: residual must exist
        assertTrue(wethResidual > 0 || usdcResidual > 0, "Geometric residual must exist");
        assertGt(residualUSD, 0, "Residual USD > 0");
    }

    /// @notice Verifies the architectural precondition described in Paper I §7.1.
    /// @dev The Geometric Siphon requires a `dustBalance[depositor][token]` storage
    ///      layout that is shared across all of a depositor's positions, regardless
    ///      of pool. A standard NFPM (Aerodrome Slipstream included) does not have
    ///      this — every position is an independent NFT and `mint()` only consumes
    ///      the exact tokens it is given. There is no shared dust pool to absorb
    ///      from when a same-range rebalance happens.
    ///
    ///      Therefore, on a stock NFPM, after Position A leaves a residual via a
    ///      range-change rebalance, Position B's same-range rebalance MUST NOT grow.
    ///      The residual is stranded in the depositor's wallet, not absorbed.
    ///
    ///      This test asserts the absence of cross-position absorption on a stock
    ///      NFPM, which directly verifies the precondition Paper I §7.1 cites as
    ///      the reason vault-per-pool architectures don't exhibit the siphon.
    function test_stockNfpmDoesNotAbsorbDust() public {
        (uint160 sqrtPriceX96, int24 currentTick) = pool.slot0();

        int24 tickSpacing = 100;
        int24 tickLower = _nearestTick(currentTick - 500, tickSpacing);
        int24 tickUpper = _nearestTick(currentTick + 500, tickSpacing);

        // Create two positions in the same range under the same depositor.
        console.log("=== Creating Positions 1 & 2 ===");
        position1 = _mintPosition(tickLower, tickUpper, 1 ether, 2500e6);
        position2 = _mintPosition(tickLower, tickUpper, 0.5 ether, 1250e6);

        _swapUSDCForWETH(1000e6);
        (sqrtPriceX96, currentTick) = pool.slot0();

        // Position 1: range-change rebalance — leaves a residual in the depositor's
        // wallet (this is Stage 1, geometric creation, and is verified separately).
        console.log("=== Rebalancing Position 1 (creates residual) ===");
        int24 tickLower2 = _nearestTick(currentTick - 1000, tickSpacing);
        int24 tickUpper2 = _nearestTick(currentTick + 1000, tickSpacing);

        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));

        (uint256 amt0, uint256 amt1) = _withdrawPosition(position1);
        position1 = _mintPosition(tickLower2, tickUpper2, amt0, amt1);

        uint256 residualWETH = weth.balanceOf(address(this)) - wethBefore;
        uint256 residualUSDC = usdc.balanceOf(address(this)) - usdcBefore;
        uint256 residualUSD = (residualWETH * ETH_PRICE_USD) / 1e18 + residualUSDC;

        console.log("Residual stranded in wallet (USD):");
        console.log(residualUSD);

        // Measure Position 2's liquidity before the same-range rebalance.
        (,,,,, int24 tL, int24 tU, uint128 liq2Before,,,,) = nfpm.positions(position2);

        // Position 2: same-range rebalance. On a stock NFPM, mint() consumes exactly
        // what it is given — there is no shared dust pool to draw from — so the
        // re-minted liquidity must equal the withdrawn liquidity. Position 2 cannot
        // grow as a side-effect of Position 1's residual.
        console.log("=== Rebalancing Position 2 (same range) ===");
        (amt0, amt1) = _withdrawPosition(position2);
        position2 = _mintPosition(tL, tU, amt0, amt1);

        (,,,,,,, uint128 liq2After,,,,) = nfpm.positions(position2);

        console.log("Liquidity before:");
        console.log(uint256(liq2Before));
        console.log("Liquidity after:");
        console.log(uint256(liq2After));

        // The architectural precondition: Position 2 must NOT have absorbed any of
        // Position 1's residual. On Slipstream, liq2After should equal liq2Before
        // (within rounding) and never exceed it.
        assertLe(
            uint256(liq2After),
            uint256(liq2Before),
            "Stock NFPM must not absorb cross-position dust (Paper I, architectural precondition)"
        );
    }

    /// @notice Control: same range = zero residual
    function test_noRangeChangeZeroResidual() public {
        (uint160 sqrtPriceX96, int24 currentTick) = pool.slot0();

        int24 tickSpacing = 100;
        int24 tickLower = _nearestTick(currentTick - 500, tickSpacing);
        int24 tickUpper = _nearestTick(currentTick + 500, tickSpacing);

        position1 = _mintPosition(tickLower, tickUpper, 1 ether, 2500e6);

        _swapUSDCForWETH(500e6);

        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));

        // Rebalance to SAME range
        console.log("=== Rebalancing to SAME range ===");
        (uint256 amt0, uint256 amt1) = _withdrawPosition(position1);
        position1 = _mintPosition(tickLower, tickUpper, amt0, amt1);

        uint256 wethResidual = weth.balanceOf(address(this)) - wethBefore;
        uint256 usdcResidual = usdc.balanceOf(address(this)) - usdcBefore;

        console.log("WETH residual:");
        console.log(wethResidual);
        console.log("USDC residual:");
        console.log(usdcResidual);

        // Should be zero or negligible
        assertLt(wethResidual, 1e12, "Same range -> minimal WETH residual");
        assertLt(usdcResidual, 1e3, "Same range -> minimal USDC residual");
    }

    /// @notice Wider range test
    function test_widerRangeAbsorbs() public {
        (uint160 sqrtPriceX96, int24 currentTick) = pool.slot0();

        int24 tickSpacing = 100;
        int24 tickLower1 = _nearestTick(currentTick - 500, tickSpacing);
        int24 tickUpper1 = _nearestTick(currentTick + 500, tickSpacing);

        position1 = _mintPosition(tickLower1, tickUpper1, 1 ether, 2500e6);

        _swapUSDCForWETH(800e6);
        (sqrtPriceX96, currentTick) = pool.slot0();

        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));

        // Rebalance to WIDER range
        int24 tickLower2 = _nearestTick(currentTick - 2000, tickSpacing);
        int24 tickUpper2 = _nearestTick(currentTick + 2000, tickSpacing);

        (uint256 amt0, uint256 amt1) = _withdrawPosition(position1);
        position1 = _mintPosition(tickLower2, tickUpper2, amt0, amt1);

        uint256 wethAfter = weth.balanceOf(address(this));
        uint256 usdcAfter = usdc.balanceOf(address(this));

        console.log("=== WIDER RANGE TEST ===");
        console.log("WETH delta:");
        console.log(wethAfter > wethBefore ? wethAfter - wethBefore : 0);
        console.log("USDC delta:");
        console.log(usdcAfter > usdcBefore ? usdcAfter - usdcBefore : 0);

        // Wider range should create positive residual
        assertTrue((wethAfter > wethBefore) || (usdcAfter > usdcBefore), "Wider range creates residual");
    }

    /// @notice Larger position test
    function test_largerPositionDonatesMore() public {
        (uint160 sqrtPriceX96, int24 currentTick) = pool.slot0();

        int24 tickSpacing = 100;
        int24 tickLower1 = _nearestTick(currentTick - 500, tickSpacing);
        int24 tickUpper1 = _nearestTick(currentTick + 500, tickSpacing);

        // Small position
        position1 = _mintPosition(tickLower1, tickUpper1, 0.5 ether, 1250e6);

        _swapUSDCForWETH(500e6);
        (sqrtPriceX96, currentTick) = pool.slot0();

        int24 tickLower2 = _nearestTick(currentTick - 1000, tickSpacing);
        int24 tickUpper2 = _nearestTick(currentTick + 1000, tickSpacing);

        uint256 wethBefore1 = weth.balanceOf(address(this));
        uint256 usdcBefore1 = usdc.balanceOf(address(this));

        (uint256 amt0, uint256 amt1) = _withdrawPosition(position1);
        position1 = _mintPosition(tickLower2, tickUpper2, amt0, amt1);

        uint256 residual1WETH = weth.balanceOf(address(this)) - wethBefore1;
        uint256 residual1USDC = usdc.balanceOf(address(this)) - usdcBefore1;
        uint256 residual1USD = (residual1WETH * ETH_PRICE_USD) / 1e18 + residual1USDC;

        // Large position
        position2 = _mintPosition(tickLower1, tickUpper1, 2 ether, 5000e6);

        uint256 wethBefore2 = weth.balanceOf(address(this));
        uint256 usdcBefore2 = usdc.balanceOf(address(this));

        (amt0, amt1) = _withdrawPosition(position2);
        position2 = _mintPosition(tickLower2, tickUpper2, amt0, amt1);

        uint256 residual2WETH = weth.balanceOf(address(this)) - wethBefore2;
        uint256 residual2USDC = usdc.balanceOf(address(this)) - usdcBefore2;
        uint256 residual2USD = (residual2WETH * ETH_PRICE_USD) / 1e18 + residual2USDC;

        console.log("=== POSITION SIZE EFFECT ===");
        console.log("Small position residual (USD):");
        console.log(residual1USD);
        console.log("Large position residual (USD):");
        console.log(residual2USD);

        assertGt(residual2USD, residual1USD, "Larger position -> larger residual");
    }

    // =============================================================================
    // Helper Functions
    // =============================================================================

    function _nearestTick(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        return compressed * tickSpacing;
    }

    function _mintPosition(int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1)
        internal
        returns (uint256 tokenId)
    {
        (tokenId,,,) = nfpm.mint(
            INonfungiblePositionManager.MintParams({
                token0: WETH,
                token1: USDC,
                tickSpacing: 100,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );
    }

    function _withdrawPosition(uint256 tokenId) internal returns (uint256 amount0, uint256 amount1) {
        (,,,,,,, uint128 liquidity,,,,) = nfpm.positions(tokenId);

        // Decrease liquidity to 0
        nfpm.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        // Collect all tokens
        (amount0, amount1) = nfpm.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
    }

    // MAX_SQRT_RATIO from Uniswap V3's TickMath. We pass `MAX - 1` as the sqrt price
    // limit so the swap is unconstrained by price (V3's swap function rejects
    // anything strictly above MAX_SQRT_RATIO when zeroForOne is false).
    uint160 internal constant MAX_SQRT_RATIO_MINUS_ONE = 1461446703485210103287273052203988822378723970341;

    function _swapUSDCForWETH(uint256 amountIn) internal {
        usdc.approve(address(pool), amountIn);

        // USDC → WETH means token1 → token0, i.e. zeroForOne = false; price moves up.
        pool.swap(
            address(this),
            false,
            int256(amountIn),
            MAX_SQRT_RATIO_MINUS_ONE,
            ""
        );
    }

    function _estimatePositionValue(uint128 liquidity, int24 tickLower, int24 tickUpper, uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 valueUSD)
    {
        // Simplified: use liquidity as proxy for value
        valueUSD = uint256(liquidity) * 1e6 / 1e18;
    }

    // Callback for swap
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) {
            weth.transfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            usdc.transfer(msg.sender, uint256(amount1Delta));
        }
    }
}
