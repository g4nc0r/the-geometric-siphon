// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Test.sol";
import {MockCLPoolV2} from "../src/MockCLPoolV2.sol";
import {MockPositionTestBase} from "./helpers/MockPositionTestBase.sol";
import {TickHelpers} from "./helpers/Tick.sol";

/// @title NewTheoremsProof
/// @notice Mock-pool verification of Theorems 4-6 from *The Geometric Siphon:
///         Existence, Equilibrium, and Directional Properties of the Residual
///         in Concentrated Liquidity Portfolios* (Ryan, 2026).
/// @dev Uses MockCLPoolV2 with exact Uniswap V3 TickMath constants for sqrt-price
///      and liquidity computations.
///
/// Theorem 4 (Residual Monotonicity, §3.7):
///   For a CL position rebalanced to a new range of equal width centred on the
///   current sqrt price s, where s has been displaced by δ from the midpoint,
///   the absolute geometric residual |ΔR| increases monotonically with |δ|
///   for |δ| ≤ w/2.
///
/// Theorem 5 (Directional Asymmetry, §3.8):
///   For a CL position in a (volatile, stablecoin) pool, symmetric sqrt-price
///   displacements ±δ from any in-range price s produce asymmetric USD-valued
///   outcomes. Measured in token1 units, the up-move position retains strictly
///   more USD value than the down-move position.
///
/// Theorem 6 (Exit Asymmetry, §3.9):
///   For a (volatile, stablecoin) pool, a below-range exit retains less USD value
///   than an above-range exit at symmetric sqrt-price displacement past the
///   respective range boundary, following from the 1/s nonlinearity in the V3
///   token0 amount equation.
contract NewTheoremsProof is MockPositionTestBase {
    // token0 is "WETH" (18 decimals), token1 is "USDC" (6 decimals).

    // Price ~2500 USDC per WETH (tick ≈ 78244)
    int24 constant BASE_TICK = 78244;
    int24 constant TICK_SPACING = 100;
    int24 constant RANGE_WIDTH = 1000; // ~10% range

    function setUp() public {
        pool = new MockCLPoolV2(BASE_TICK);
        token0Balance = 100 ether;
        token1Balance = 250_000e6;
    }
    
    // =========================================================================
    // Theorem 4: Residual Monotonicity
    // |ΔR| increases monotonically with displacement magnitude.
    // =========================================================================

    function test_theorem4_residualMonotonicity() public {
        console.log("Theorem 4: residual monotonicity sweep");

        int24 tickLower = _nearest(BASE_TICK - RANGE_WIDTH / 2);
        int24 tickUpper = _nearest(BASE_TICK + RANGE_WIDTH / 2);

        uint256 deposit0 = 2 ether;
        uint256 deposit1 = 5000e6;

        uint256 prevResidual = 0;
        uint256 monotoneViolations = 0;

        // Sweep displacements: 100, 200, 300, 400, 500, 600, 700, 800 ticks
        int24[8] memory displacements = [int24(100), 200, 300, 400, 500, 600, 700, 800];

        uint256 baseSnap = vm.snapshotState();

        for (uint256 d = 0; d < displacements.length; d++) {
            vm.revertToState(baseSnap);
            baseSnap = vm.snapshotState();

            Position memory pos = _createPosition(tickLower, tickUpper, deposit0, deposit1);
            
            // Move price UP by displacement ticks
            int24 newTick = _nearest(BASE_TICK + displacements[d]);
            pool.movePriceToTick(newTick);
            
            // Measure total value before rebalance
            (uint256 w0, uint256 w1) = pool.getAmountsForLiquidity(
                pos.liquidity, pos.tickLower, pos.tickUpper
            );
            uint256 valueBefore = _valueAtPoolPrice(w0, w1);
            
            (w0, w1) = _withdrawPosition(pos);
            
            // Create new position centered on new tick
            int24 newLower = _nearest(newTick - RANGE_WIDTH / 2);
            int24 newUpper = _nearest(newTick + RANGE_WIDTH / 2);
            
            Position memory newPos = _createPosition(newLower, newUpper, w0, w1);
            
            // Measure value deployed in new position
            (uint256 a0, uint256 a1) = pool.getAmountsForLiquidity(
                newPos.liquidity, newPos.tickLower, newPos.tickUpper
            );
            uint256 valueAfter = _valueAtPoolPrice(a0, a1);
            
            // Residual = tokens not deployed (left as dust)
            uint256 dustToken0 = w0 > a0 ? w0 - a0 : 0;
            uint256 dustToken1 = w1 > a1 ? w1 - a1 : 0;
            uint256 dustUsd = _valueAtPoolPrice(dustToken0, dustToken1);
            
            console.log("Displacement +%d ticks:", uint256(int256(displacements[d])));
            console.log("  Value before: $%d, after: $%d", valueBefore / 1e6, valueAfter / 1e6);
            console.log("  Dust: %d token0 + %d token1 = $%d", dustToken0, dustToken1, dustUsd / 1e6);

            if (d > 0 && dustUsd < prevResidual) {
                monotoneViolations++;
                console.log("  WARNING: monotonicity violated!");
            }
            prevResidual = dustUsd;
        }
        
        // Theorem 4: residual must be monotonically non-decreasing across the sweep.
        assertEq(monotoneViolations, 0, "Theorem 4: residual increases monotonically with displacement");
        console.log("\nTheorem 4 verified: 0 monotonicity violations across 8 displacement levels");
    }
    
    // =========================================================================
    // Theorem 5: Directional Asymmetry
    // For symmetric sqrt-price moves s ± δ inside the range, the up-move position
    // is worth strictly more in token1 than the down-move position, and the gap
    // is 4 L δ (1 - s / s_b).
    // =========================================================================

    function test_theorem5_directionalAsymmetry() public {
        console.log("Theorem 5: directional asymmetry sweep");

        int24 tickLower = _nearest(BASE_TICK - RANGE_WIDTH / 2);
        int24 tickUpper = _nearest(BASE_TICK + RANGE_WIDTH / 2);
        uint256 sA = pool.getSqrtRatioAtTick(tickLower);
        uint256 sB = pool.getSqrtRatioAtTick(tickUpper);
        uint256 s0 = pool.sqrtPriceX96();

        Position memory pos = _createPosition(tickLower, tickUpper, 2 ether, 5000e6);
        console.log("Initial value: $%d", _positionValue(pos) / 1e6);

        // Displacements of s, in units of 0.01% of s. All keep s ± δ inside the range.
        uint256[5] memory dispBps = [uint256(50), 100, 150, 200, 225];

        for (uint256 d = 0; d < dispBps.length; d++) {
            uint256 delta = s0 * dispBps[d] / 10000;
            require(s0 + delta < sB && s0 - delta > sA, "displacement leaves the range");

            pool.movePriceToSqrtPrice(uint160(s0 + delta));
            uint256 vUp = _positionValue(pos);

            pool.movePriceToSqrtPrice(uint160(s0 - delta));
            uint256 vDown = _positionValue(pos);

            // Closed form of the gap: V(s+δ) - V(s-δ) = 4 L δ (1 - s / s_b)
            uint256 expectedGap = (uint256(pos.liquidity) * 4 * delta / sB) * (sB - s0) >> 96;

            console.log("Displacement +/-%d bps of s:", dispBps[d]);
            console.log("  V_up: $%d, V_down: $%d", vUp / 1e6, vDown / 1e6);
            console.log("  Gap: $%d, closed form: $%d", (vUp - vDown) / 1e6, expectedGap / 1e6);

            assertGt(vUp, vDown, "Theorem 5: V(s + delta) > V(s - delta)");
            assertApproxEqRel(vUp - vDown, expectedGap, 1e15, "Theorem 5: gap matches 4 L delta (1 - s/s_b)");
        }

        pool.movePriceToSqrtPrice(uint160(s0));
        console.log("\nTheorem 5 verified at %d displacement levels", dispBps.length);
    }

    // =========================================================================
    // Theorem 6: Exit Asymmetry
    // At a sqrt-price distance d past the boundary, the below-range position
    // (all token0) is worth strictly less in token1 than the above-range
    // position (all token1), and V_below / V_above = (s_a - d)^2 / (s_a s_b).
    // =========================================================================

    function test_theorem6_exitAsymmetry() public {
        console.log("Theorem 6: exit asymmetry sweep");

        int24 tickLower = _nearest(BASE_TICK - RANGE_WIDTH / 2);
        int24 tickUpper = _nearest(BASE_TICK + RANGE_WIDTH / 2);
        uint256 sA = pool.getSqrtRatioAtTick(tickLower);
        uint256 sB = pool.getSqrtRatioAtTick(tickUpper);
        uint256 s0 = pool.sqrtPriceX96();

        Position memory pos = _createPosition(tickLower, tickUpper, 2 ether, 5000e6);
        console.log("Initial value: $%d", _positionValue(pos) / 1e6);

        // Distances past the boundary, in units of 0.01% of the starting sqrt price.
        uint256[5] memory distBps = [uint256(25), 50, 100, 150, 250];
        uint256 prevBelow = type(uint256).max;

        for (uint256 d = 0; d < distBps.length; d++) {
            uint256 dist = s0 * distBps[d] / 10000;

            pool.movePriceToSqrtPrice(uint160(sB + dist));
            (uint256 above0, uint256 above1) = pool.getAmountsForLiquidity(pos.liquidity, tickLower, tickUpper);
            uint256 vAbove = _valueAtPoolPrice(above0, above1);

            pool.movePriceToSqrtPrice(uint160(sA - dist));
            (uint256 below0, uint256 below1) = pool.getAmountsForLiquidity(pos.liquidity, tickLower, tickUpper);
            uint256 vBelow = _valueAtPoolPrice(below0, below1);

            // Corollary 6.1: V_below / V_above = (s_a - d)^2 / (s_a s_b)
            uint256 expectedBelow = (vAbove * (sA - dist) / sA) * (sA - dist) / sB;

            console.log("Exit distance %d bps of s:", distBps[d]);
            console.log("  V_above: $%d, V_below: $%d", vAbove / 1e6, vBelow / 1e6);
            console.log("  Closed-form V_below: $%d", expectedBelow / 1e6);

            assertEq(above0, 0, "above the range the position holds token1 only");
            assertEq(below1, 0, "below the range the position holds token0 only");
            assertGt(vAbove, vBelow, "Theorem 6: V_above > V_below");
            assertApproxEqRel(vBelow, expectedBelow, 1e15, "Corollary 6.1: closed-form exit ratio");
            assertLt(vBelow, prevBelow, "V_below falls as the exit distance grows");
            prevBelow = vBelow;
        }

        pool.movePriceToSqrtPrice(uint160(s0));
        console.log("\nTheorem 6 verified at %d exit distances", distBps.length);
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _nearest(int24 tick) internal pure returns (int24) {
        return TickHelpers.nearest(tick, TICK_SPACING);
    }

    /// @notice Value of a position in token1 units at the pool's current price.
    function _positionValue(Position memory pos) internal view returns (uint256) {
        (uint256 a0, uint256 a1) = pool.getAmountsForLiquidity(pos.liquidity, pos.tickLower, pos.tickUpper);
        return _valueAtPoolPrice(a0, a1);
    }
}
