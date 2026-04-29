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

/// @title DirectionalExitForkProof
/// @notice Live-fork verification of Theorems 5 and 6 against unmodified
///         Aerodrome Slipstream contracts on Base mainnet, complementing the
///         mock-pool tests in NewTheoremsProof.t.sol whose below-direction
///         values floor to zero under integer arithmetic at depressed token0
///         prices.
contract DirectionalExitForkProof is Test {
    address constant NFPM = 0x827922686190790b37229fd06084350E74485b72;
    address constant FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /// @dev Pinned to 2026-03-10 10:42 UTC, mid-Phase 2 of the paper's data
    ///      window. The qualitative inequalities hold at every block;
    ///      pinning makes the captured numerical values bit-reproducible.
    uint256 constant BASE_BLOCK_PIN = 43_175_000;

    int24 constant TICK_SPACING = 100;

    INonfungiblePositionManager nfpm;
    IUniswapV3Pool pool;
    IUniswapV3Factory factory;
    IERC20 weth;
    IERC20 usdc;

    function setUp() public {
        vm.createSelectFork("base", BASE_BLOCK_PIN);

        nfpm = INonfungiblePositionManager(NFPM);
        factory = IUniswapV3Factory(FACTORY);
        weth = IERC20(WETH);
        usdc = IERC20(USDC);

        pool = IUniswapV3Pool(factory.getPool(WETH, USDC, TICK_SPACING));
        require(address(pool) != address(0), "Pool not found");

        // WETH (0x4200..) < USDC (0x8335..) so token0 = WETH (volatile),
        // token1 = USDC (stablecoin) - the forward ordering of Theorems 5 & 6.
        require(pool.token0() == WETH, "Unexpected pool ordering");
        require(pool.token1() == USDC, "Unexpected pool ordering");

        // Funded for multi-million-dollar swaps; pool is deep enough that
        // smaller budgets cannot push past either range boundary.
        deal(WETH, address(this), 5000 ether);
        deal(USDC, address(this), 20_000_000e6);

        weth.approve(NFPM, type(uint256).max);
        usdc.approve(NFPM, type(uint256).max);
    }

    /// @notice Theorem 5: V_up > V_down for symmetric in-range displacement.
    function test_theorem5_directionalAsymmetryOnSlipstream() public {
        (, int24 t0) = pool.slot0();
        int24 tickLower = TickHelpers.nearest(t0 - 1000, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(t0 + 1000, TICK_SPACING);

        uint256 tokenId = _mintPosition(tickLower, tickUpper, 1 ether, 2_500e6);
        uint256 snap = vm.snapshotState();

        _swapUSDCForWETH(50_000e6);
        (uint160 s_up, int24 t_up) = pool.slot0();
        uint256 V_up = _positionValueUSDC(tokenId, s_up);

        vm.revertToState(snap);

        _swapWETHForUSDC(20 ether);
        (uint160 s_down, int24 t_down) = pool.slot0();
        uint256 V_down = _positionValueUSDC(tokenId, s_down);

        console.log("up displacement (ticks)  :", uint256(int256(t_up - t0)));
        console.log("down displacement (ticks):", uint256(int256(t0 - t_down)));
        console.log("V_up   (USDC, 6dp):", V_up);
        console.log("V_down (USDC, 6dp):", V_down);

        assertGt(V_up, V_down, "Theorem 5: V_up > V_down");
    }

    /// @notice Theorem 6: V_above > V_below at exit past the respective boundary.
    function test_theorem6_exitAsymmetryOnSlipstream() public {
        (, int24 t0) = pool.slot0();
        int24 tickLower = TickHelpers.nearest(t0 - 100, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(t0 + 100, TICK_SPACING);

        uint256 tokenId = _mintPosition(tickLower, tickUpper, 1 ether, 2_500e6);
        uint256 snap = vm.snapshotState();

        _swapUSDCForWETH(15_000_000e6);
        (uint160 s_above, int24 t_above) = pool.slot0();
        require(t_above > tickUpper, "Above-exit swap did not push past upper bound");
        uint256 V_above = _positionValueUSDC(tokenId, s_above);

        vm.revertToState(snap);

        _swapWETHForUSDC(4000 ether);
        (uint160 s_below, int24 t_below) = pool.slot0();
        require(t_below < tickLower, "Below-exit swap did not push past lower bound");
        uint256 V_below = _positionValueUSDC(tokenId, s_below);

        console.log("ticks past upper bound:", uint256(int256(t_above - tickUpper)));
        console.log("ticks past lower bound:", uint256(int256(tickLower - t_below)));
        console.log("V_above (USDC, 6dp):", V_above);
        console.log("V_below (USDC, 6dp):", V_below);

        assertGt(V_above, V_below, "Theorem 6: V_above > V_below");
    }

    function _mintPosition(int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1)
        internal
        returns (uint256 tokenId)
    {
        (tokenId,,,) = nfpm.mint(
            INonfungiblePositionManager.MintParams({
                token0: WETH,
                token1: USDC,
                tickSpacing: TICK_SPACING,
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

    function _swapUSDCForWETH(uint256 amountIn) internal {
        usdc.approve(address(pool), amountIn);
        // token1 -> token0; zeroForOne = false; price up.
        pool.swap(address(this), false, int256(amountIn), V3Bounds.MAX_SQRT_RATIO_MINUS_ONE, "");
    }

    function _swapWETHForUSDC(uint256 amountIn) internal {
        weth.approve(address(pool), amountIn);
        // token0 -> token1; zeroForOne = true; price down.
        pool.swap(address(this), true, int256(amountIn), V3Bounds.MIN_SQRT_RATIO_PLUS_ONE, "");
    }

    /// @dev Position value in USDC raw units. token1 (USDC) is taken at face
    ///      value; token0 (WETH) is converted at the pool's current price via
    ///      sqrtPriceX96^2 / 2^192 (the V3 price encoding for asymmetric-decimal
    ///      pairs already absorbs the 10^12 decimal-difference factor).
    function _positionValueUSDC(uint256 tokenId, uint160 sqrtPriceX96) internal view returns (uint256) {
        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = nfpm.positions(tokenId);
        (uint256 amount0, uint256 amount1) = _amountsForLiquidity(
            sqrtPriceX96, _getSqrtRatioAtTick(tickLower), _getSqrtRatioAtTick(tickUpper), liquidity
        );
        uint256 priceQ192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        return (amount0 * priceQ192) / (1 << 192) + amount1;
    }

    /// @dev Uniswap V3 LiquidityAmounts.getAmountsForLiquidity, inlined.
    function _amountsForLiquidity(uint160 sqrtPriceX96, uint160 sA, uint160 sB, uint128 liquidity)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        if (sA > sB) (sA, sB) = (sB, sA);
        if (sqrtPriceX96 <= sA) {
            amount0 = _getAmount0(sA, sB, liquidity);
        } else if (sqrtPriceX96 < sB) {
            amount0 = _getAmount0(sqrtPriceX96, sB, liquidity);
            amount1 = _getAmount1(sA, sqrtPriceX96, liquidity);
        } else {
            amount1 = _getAmount1(sA, sB, liquidity);
        }
    }

    function _getAmount0(uint160 sA, uint160 sB, uint128 liquidity) internal pure returns (uint256) {
        if (sA > sB) (sA, sB) = (sB, sA);
        require(sA > 0, "sA > 0");
        return (uint256(liquidity) << 96) * (sB - sA) / sB / sA;
    }

    function _getAmount1(uint160 sA, uint160 sB, uint128 liquidity) internal pure returns (uint256) {
        if (sA > sB) (sA, sB) = (sB, sA);
        return uint256(liquidity) * (sB - sA) / (1 << 96);
    }

    /// @dev TickMath.getSqrtRatioAtTick, verbatim from Uniswap V3 core.
    function _getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= 887272, "T");

        uint256 ratio =
            absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;
        return uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == address(pool), "callback: not pool");
        if (amount0Delta > 0) weth.transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) usdc.transfer(msg.sender, uint256(amount1Delta));
    }
}
