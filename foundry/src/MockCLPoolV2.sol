// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockCLPoolV2 - Improved CL Pool with accurate tick math
/// @notice Uses proper exponential tick→sqrtPrice for theorem proofs
contract MockCLPoolV2 {
    uint160 public sqrtPriceX96;
    int24 public tick;
    
    uint256 constant Q96 = 2**96;
    
    constructor(uint160 _sqrtPriceX96, int24 _tick) {
        sqrtPriceX96 = _sqrtPriceX96 == 0 ? getSqrtRatioAtTick(_tick) : _sqrtPriceX96;
        tick = _tick;
    }
    
    /// @notice Get token amounts for given liquidity and range
    function getAmountsForLiquidity(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) public view returns (uint256 amount0, uint256 amount1) {
        uint160 sqrtPriceLower = getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpper = getSqrtRatioAtTick(tickUpper);
        uint160 currentPrice = sqrtPriceX96;
        
        if (currentPrice <= sqrtPriceLower) {
            amount0 = getAmount0ForLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
            amount1 = 0;
        } else if (currentPrice < sqrtPriceUpper) {
            amount0 = getAmount0ForLiquidity(currentPrice, sqrtPriceUpper, liquidity);
            amount1 = getAmount1ForLiquidity(sqrtPriceLower, currentPrice, liquidity);
        } else {
            amount0 = 0;
            amount1 = getAmount1ForLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
        }
    }
    
    /// @notice Get liquidity for given token amounts and range
    function getLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) public view returns (uint128 liquidity) {
        uint160 sqrtPriceLower = getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpper = getSqrtRatioAtTick(tickUpper);
        uint160 currentPrice = sqrtPriceX96;
        
        if (currentPrice <= sqrtPriceLower) {
            liquidity = getLiquidityForAmount0(sqrtPriceLower, sqrtPriceUpper, amount0);
        } else if (currentPrice < sqrtPriceUpper) {
            uint128 liq0 = getLiquidityForAmount0(currentPrice, sqrtPriceUpper, amount0);
            uint128 liq1 = getLiquidityForAmount1(sqrtPriceLower, currentPrice, amount1);
            liquidity = liq0 < liq1 ? liq0 : liq1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtPriceLower, sqrtPriceUpper, amount1);
        }
    }
    
    /// @notice Move price to new tick
    function movePriceToTick(int24 newTick) external {
        tick = newTick;
        sqrtPriceX96 = getSqrtRatioAtTick(newTick);
    }
    
    /// @notice Move price to exact sqrtPriceX96
    function movePriceExact(uint160 newSqrtPrice, int24 newTick) external {
        sqrtPriceX96 = newSqrtPrice;
        tick = newTick;
    }
    
    /// @notice Get the USD value of a position (token0 = volatile, token1 = stable at $1)
    /// @param token0PriceUsd Price of token0 in USD (6 decimals, e.g. 2500e6 = $2500)
    function getPositionValueUsd(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 token0PriceUsd
    ) external view returns (uint256 valueUsd) {
        (uint256 amount0, uint256 amount1) = getAmountsForLiquidity(liquidity, tickLower, tickUpper);
        // amount0 is 18 decimals (WETH), amount1 is 6 decimals (USDC)
        // token0PriceUsd is 6 decimals
        valueUsd = (amount0 * token0PriceUsd) / 1e18 + amount1;
    }
    
    // =============================================================================
    // Accurate tick math using Uniswap V3's approach
    // =============================================================================
    
    /// @notice Compute sqrtPriceX96 from tick using iterative squaring
    /// @dev sqrtPrice = sqrt(1.0001^tick) * 2^96 = 1.00005^tick * 2^96
    /// Uses the Uniswap V3 TickMath approach with precomputed constants
    function getSqrtRatioAtTick(int24 _tick) public pure returns (uint160) {
        uint256 absTick = _tick < 0 ? uint256(-int256(_tick)) : uint256(int256(_tick));
        require(absTick <= 887272, "T");
        
        // Start with ratio = 1 (in Q128.128)
        uint256 ratio = 0x100000000000000000000000000000000;
        
        // Multiply by precomputed powers of sqrt(1.0001)
        // These are the exact constants from Uniswap V3 TickMath
        if (absTick & 0x1 != 0) ratio = (ratio * 0xfffcb933bd6fad37aa2d162d1a594001) >> 128;
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
        
        if (_tick > 0) ratio = type(uint256).max / ratio;
        
        // Convert from Q128.128 to Q64.96
        return uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }
    
    // =============================================================================
    // Internal Math Functions (unchanged from V1)
    // =============================================================================
    
    function getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return mulDiv(
            uint256(liquidity) * Q96,
            sqrtRatioBX96 - sqrtRatioAX96,
            sqrtRatioBX96
        ) / sqrtRatioAX96;
    }
    
    function getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, Q96);
    }
    
    function getLiquidityForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = mulDiv(sqrtRatioAX96, sqrtRatioBX96, Q96);
        liquidity = uint128(mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96));
    }
    
    function getLiquidityForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        liquidity = uint128(mulDiv(amount1, Q96, sqrtRatioBX96 - sqrtRatioAX96));
    }
    
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        require(denominator > 0);
        result = (a * b) / denominator;
    }
}
