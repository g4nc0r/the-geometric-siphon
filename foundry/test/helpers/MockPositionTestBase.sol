// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MockCLPool} from "../../src/MockCLPool.sol";

/// @title MockPositionTestBase
/// @notice Shared scaffolding for the mock-pool test contracts: a
///         token-balance pair, a `Position` record, and the create / withdraw
///         flow that underlies every theorem regression test.
abstract contract MockPositionTestBase is Test {
    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    /// @dev Typed against the base `MockCLPool` so this scaffold accepts both
    ///      `MockCLPool` and the V3-exact `MockCLPoolV2` (assigned covariantly
    ///      in the subclass `setUp`). The `getSqrtRatioAtTick` override is
    ///      dispatched via the vtable.
    MockCLPool internal pool;
    uint256 internal token0Balance;
    uint256 internal token1Balance;

    function _createPosition(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal returns (Position memory pos) {
        uint128 liquidity = pool.getLiquidityForAmounts(
            amount0Desired, amount1Desired, tickLower, tickUpper
        );
        (uint256 amount0, uint256 amount1) = pool.getAmountsForLiquidity(
            liquidity, tickLower, tickUpper
        );
        require(token0Balance >= amount0, "Insufficient token0");
        require(token1Balance >= amount1, "Insufficient token1");
        token0Balance -= amount0;
        token1Balance -= amount1;
        pos = Position(tickLower, tickUpper, liquidity);
    }

    /// @notice Value of a token pair in token1 units at a given sqrt price.
    /// @dev The mock pools carry no decimal offset, so token0 is valued at the
    ///      pool's raw price, sqrtPriceX96^2 / 2^192.
    function _valueAtSqrtPrice(uint256 amount0, uint256 amount1, uint160 sqrtPriceX96_)
        internal
        pure
        returns (uint256)
    {
        uint256 s = uint256(sqrtPriceX96_);
        return (((amount0 * s) >> 96) * s >> 96) + amount1;
    }

    /// @notice Value of a token pair in token1 units at the pool's current price.
    function _valueAtPoolPrice(uint256 amount0, uint256 amount1) internal view returns (uint256) {
        return _valueAtSqrtPrice(amount0, amount1, pool.sqrtPriceX96());
    }

    function _withdrawPosition(Position memory pos)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = pool.getAmountsForLiquidity(
            pos.liquidity, pos.tickLower, pos.tickUpper
        );
        token0Balance += amount0;
        token1Balance += amount1;
    }
}
