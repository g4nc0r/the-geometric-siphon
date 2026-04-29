// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {
    IERC20,
    INonfungiblePositionManager,
    IUniswapV3Pool,
    IUniswapV3Factory,
    V3Bounds
} from "./interfaces/Slipstream.sol";
import {TickHelpers} from "./helpers/Tick.sol";

/// @title GeometricResidualProof
/// @notice Live-fork verification of Theorem 1 and the §7.1 architectural
///         precondition against the unmodified Aerodrome Slipstream
///         NonfungiblePositionManager on Base.
///
/// Theorem 1 (Geometric Residual Existence, §3.4):
///   A CL position rebalanced to a new range whose V3 amount equations
///   demand a different token ratio produces a strictly positive
///   geometric residual ΔR > 0; a same-range rebalance produces none.
///
/// §7.1 Architectural precondition:
///   Cross-position absorption requires a depositor-level shared dust
///   balance. A stock NFPM (Slipstream included) treats every position as
///   an independent NFT; mint() consumes only the tokens it is given,
///   so Position B's same-range rebalance cannot grow from Position A's
///   residual. This file's `test_section7_1_*` test asserts that absence
///   on live-chain Slipstream contracts.
contract GeometricResidualProof is Test {
    // Base mainnet addresses
    address constant NFPM = 0x827922686190790b37229fd06084350E74485b72;
    address constant FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    INonfungiblePositionManager nfpm;
    IUniswapV3Pool pool;
    IUniswapV3Factory factory;
    IERC20 weth;
    IERC20 usdc;

    uint256 position1;
    uint256 position2;

    // Price oracle (simplified - using fixed price for USD conversion)
    uint256 constant ETH_PRICE_USD = 2500e6; // $2500 USDC per WETH

    // Pinned to 2026-03-10 10:42 UTC, mid-Phase 2 of the paper's data window.
    // Re-running requires a Base archive RPC.
    uint256 constant FORK_BLOCK = 43_175_000;

    // Same-range integer-rounding noise floors:
    //   1e12 wei  ≈ 1 nano-WETH (≈ $0.0000025 at ETH_PRICE_USD)
    //   1e3 units ≈ 0.001 USDC
    uint256 constant SAME_RANGE_WETH_TOLERANCE = 1e12;
    uint256 constant SAME_RANGE_USDC_TOLERANCE = 1e3;

    function setUp() public {
        vm.createSelectFork("base", FORK_BLOCK);

        nfpm = INonfungiblePositionManager(NFPM);
        factory = IUniswapV3Factory(FACTORY);
        weth = IERC20(WETH);
        usdc = IERC20(USDC);

        // Get WETH/USDC pool with tickSpacing=100
        pool = IUniswapV3Pool(factory.getPool(WETH, USDC, 100));
        require(address(pool) != address(0), "Pool not found");

        // Fund this contract using deal
        deal(WETH, address(this), 10 ether);
        deal(USDC, address(this), 25000e6);

        weth.approve(NFPM, type(uint256).max);
        usdc.approve(NFPM, type(uint256).max);
    }

    /// @notice Stage 1: Prove range change creates geometric residual
    function test_theorem1_rangeChangeCreatesResidual() public {
        (, int24 currentTick) = pool.slot0();

        // Create position 1: narrow range around current price
        int24 tickSpacing = 100;
        int24 tickLower1 = TickHelpers.nearest(currentTick - 500, tickSpacing);
        int24 tickUpper1 = TickHelpers.nearest(currentTick + 500, tickSpacing);

        position1 = _mintPosition(tickLower1, tickUpper1, 1 ether, 2500e6);

        // Move price via swap
        _swapUSDCForWETH(1000e6);

        (, currentTick) = pool.slot0();

        // Measure balances before rebalance
        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));

        // Rebalance position 1: withdraw from old range, mint into new range (wider)
        int24 tickLower2 = TickHelpers.nearest(currentTick - 1000, tickSpacing);
        int24 tickUpper2 = TickHelpers.nearest(currentTick + 1000, tickSpacing);

        (uint256 amount0, uint256 amount1) = _withdrawPosition(position1);
        position1 = _mintPosition(tickLower2, tickUpper2, amount0, amount1);

        // Measure residual
        uint256 wethAfter = weth.balanceOf(address(this));
        uint256 usdcAfter = usdc.balanceOf(address(this));

        uint256 wethResidual = wethAfter - wethBefore;
        uint256 usdcResidual = usdcAfter - usdcBefore;

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

    /// @notice Verifies the architectural precondition described in §7.1.
    /// @dev The Geometric Siphon requires a `dustBalance[depositor][token]` storage
    ///      layout that is shared across all of a depositor's positions, regardless
    ///      of pool. A standard NFPM (Aerodrome Slipstream included) does not
    ///      have this; every position is an independent NFT and `mint()` only
    ///      consumes the exact tokens it is given. There is no shared dust pool
    ///      to absorb from when a same-range rebalance happens.
    ///
    ///      Therefore, on a stock NFPM, after Position A leaves a residual via a
    ///      range-change rebalance, Position B's same-range rebalance MUST NOT grow.
    ///      The residual is stranded in the depositor's wallet, not absorbed.
    ///
    ///      This test asserts the absence of cross-position absorption on a stock
    ///      NFPM, which directly verifies the precondition §7.1 cites as the
    ///      reason vault-per-pool architectures do not exhibit the siphon.
    function test_section7_1_stockNfpmDoesNotAbsorbDust() public {
        (, int24 currentTick) = pool.slot0();

        int24 tickSpacing = 100;
        int24 tickLower = TickHelpers.nearest(currentTick - 500, tickSpacing);
        int24 tickUpper = TickHelpers.nearest(currentTick + 500, tickSpacing);

        // Create two positions in the same range under the same depositor.
        position1 = _mintPosition(tickLower, tickUpper, 1 ether, 2500e6);
        position2 = _mintPosition(tickLower, tickUpper, 0.5 ether, 1250e6);

        _swapUSDCForWETH(1000e6);
        (, currentTick) = pool.slot0();

        // Position 1: range-change rebalance, leaves a residual in the
        // depositor's wallet (Stage 1, geometric creation, verified separately).
        int24 tickLower2 = TickHelpers.nearest(currentTick - 1000, tickSpacing);
        int24 tickUpper2 = TickHelpers.nearest(currentTick + 1000, tickSpacing);

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

        // Position 2: same-range rebalance. On a stock NFPM, mint() consumes
        // exactly what it is given (no shared dust pool to draw from), so the
        // re-minted liquidity must equal the withdrawn liquidity. Position 2
        // cannot grow as a side-effect of Position 1's residual.
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
            "Stock NFPM must not absorb cross-position dust (architectural precondition, sec 7.1)"
        );
    }

    /// @notice Control: same range = zero residual
    function test_theorem1_noRangeChangeZeroResidual() public {
        (, int24 currentTick) = pool.slot0();

        int24 tickSpacing = 100;
        int24 tickLower = TickHelpers.nearest(currentTick - 500, tickSpacing);
        int24 tickUpper = TickHelpers.nearest(currentTick + 500, tickSpacing);

        position1 = _mintPosition(tickLower, tickUpper, 1 ether, 2500e6);

        _swapUSDCForWETH(500e6);

        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));

        // Rebalance to SAME range
        (uint256 amt0, uint256 amt1) = _withdrawPosition(position1);
        position1 = _mintPosition(tickLower, tickUpper, amt0, amt1);

        uint256 wethResidual = weth.balanceOf(address(this)) - wethBefore;
        uint256 usdcResidual = usdc.balanceOf(address(this)) - usdcBefore;

        console.log("WETH residual:");
        console.log(wethResidual);
        console.log("USDC residual:");
        console.log(usdcResidual);

        // Should be zero or negligible
        assertLt(wethResidual, SAME_RANGE_WETH_TOLERANCE, "Same range -> minimal WETH residual");
        assertLt(usdcResidual, SAME_RANGE_USDC_TOLERANCE, "Same range -> minimal USDC residual");
    }

    /// @notice Larger position test: same range-change rebalance, two
    ///         deposit sizes from a clean pool snapshot. Uses snapshotState
    ///         so that the large-position run does not see any state left
    ///         over from the small-position run.
    function test_theorem1_largerPositionDonatesMore() public {
        uint256 snap = vm.snapshotState();

        uint256 residual1USD = _measureRebalanceResidual(0.5 ether, 1250e6);

        vm.revertToState(snap);

        uint256 residual2USD = _measureRebalanceResidual(2 ether, 5000e6);

        console.log("Small position residual (USD):");
        console.log(residual1USD);
        console.log("Large position residual (USD):");
        console.log(residual2USD);

        assertGt(residual2USD, residual1USD, "Larger position -> larger residual");
    }

    /// @dev Mints a position around the current tick at the given deposit
    ///      sizes, swaps to displace, rebalances to a wider range, and
    ///      returns the residual stranded in the depositor's wallet (USD).
    function _measureRebalanceResidual(uint256 amount0, uint256 amount1)
        internal
        returns (uint256 residualUSD)
    {
        (, int24 currentTick) = pool.slot0();

        int24 tickSpacing = 100;
        int24 tickLowerOld = TickHelpers.nearest(currentTick - 500, tickSpacing);
        int24 tickUpperOld = TickHelpers.nearest(currentTick + 500, tickSpacing);

        uint256 tokenId = _mintPosition(tickLowerOld, tickUpperOld, amount0, amount1);

        _swapUSDCForWETH(500e6);
        (, currentTick) = pool.slot0();

        int24 tickLowerNew = TickHelpers.nearest(currentTick - 1000, tickSpacing);
        int24 tickUpperNew = TickHelpers.nearest(currentTick + 1000, tickSpacing);

        uint256 wethBefore = weth.balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));

        (uint256 amt0, uint256 amt1) = _withdrawPosition(tokenId);
        _mintPosition(tickLowerNew, tickUpperNew, amt0, amt1);

        uint256 residualWETH = weth.balanceOf(address(this)) - wethBefore;
        uint256 residualUSDC = usdc.balanceOf(address(this)) - usdcBefore;
        residualUSD = (residualWETH * ETH_PRICE_USD) / 1e18 + residualUSDC;
    }

    // =============================================================================
    // Helper Functions
    // =============================================================================

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

    function _swapUSDCForWETH(uint256 amountIn) internal {
        usdc.approve(address(pool), amountIn);

        // USDC → WETH means token1 → token0, i.e. zeroForOne = false; price moves up.
        // MAX_SQRT_RATIO_MINUS_ONE makes the swap unconstrained by price.
        pool.swap(
            address(this),
            false,
            int256(amountIn),
            V3Bounds.MAX_SQRT_RATIO_MINUS_ONE,
            ""
        );
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == address(pool), "callback: not pool");
        if (amount0Delta > 0) {
            weth.transfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            usdc.transfer(msg.sender, uint256(amount1Delta));
        }
    }
}
