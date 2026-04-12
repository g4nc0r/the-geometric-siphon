// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockCLPoolV2} from "../src/MockCLPoolV2.sol";

/// @title NewTheoremsProof
/// @notice Foundry verification of the directional theorems from
///         "The Geometric Siphon II: Directional Properties" (Ryan, SSRN 6481498).
/// @dev Uses MockCLPoolV2 with exact Uniswap V3 TickMath constants for sqrt-price
///      and liquidity computations.
///
/// Theorem 4 — Residual Monotonicity (§2.1):
///   For a CL position rebalanced to a new range of equal width centred on the
///   current sqrt price s, where s has been displaced by δ from the midpoint,
///   the absolute geometric residual |ΔR| increases monotonically with |δ|
///   for |δ| ≤ w/2.
///
/// Theorem 5 — Directional Asymmetry (§2.2):
///   For a CL position in a (volatile, stablecoin) pool, symmetric sqrt-price
///   displacements ±δ from any in-range price s produce asymmetric USD-valued
///   outcomes. Measured in token1 units, the up-move position retains strictly
///   more USD value than the down-move position.
///
/// Theorem 6 — Exit Asymmetry (§2.3):
///   For a (volatile, stablecoin) pool, a below-range exit retains less USD value
///   than an above-range exit at symmetric sqrt-price displacement past the
///   respective range boundary, following from the 1/s nonlinearity in the V3
///   token0 amount equation.
contract NewTheoremsProof is Test {
    MockCLPoolV2 pool;
    
    uint256 token0Balance;  // "WETH" - 18 decimals
    uint256 token1Balance;  // "USDC" - 6 decimals
    
    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }
    
    // Price ~2500 USDC per WETH (tick ≈ 78244)
    int24 constant BASE_TICK = 78244;
    int24 constant TICK_SPACING = 100;
    int24 constant RANGE_WIDTH = 1000; // ~10% range
    
    function setUp() public {
        pool = new MockCLPoolV2(0, BASE_TICK);
        token0Balance = 100 ether;
        token1Balance = 250_000e6;
    }
    
    // =========================================================================
    // Theorem 4 — Residual Monotonicity
    // |ΔR| increases monotonically with displacement magnitude.
    // =========================================================================

    function test_theorem4_residualMonotonicity() public {
        console.log("\n=== Theorem 4: Residual Monotonicity ===");
        console.log("Verifying: larger displacement -> larger residual");
        
        int24 tickLower = _nearest(BASE_TICK - RANGE_WIDTH / 2);
        int24 tickUpper = _nearest(BASE_TICK + RANGE_WIDTH / 2);
        
        uint256 deposit0 = 2 ether;
        uint256 deposit1 = 5000e6;
        
        uint256 prevResidual = 0;
        uint256 monotoneViolations = 0;
        
        // Sweep displacements: 100, 200, 300, 400, 500, 600, 700, 800 ticks
        int24[8] memory displacements = [int24(100), 200, 300, 400, 500, 600, 700, 800];
        
        for (uint256 d = 0; d < displacements.length; d++) {
            _resetPool();
            token0Balance = 100 ether;
            token1Balance = 250_000e6;
            
            Position memory pos = _createPosition(tickLower, tickUpper, deposit0, deposit1);
            
            // Move price UP by displacement ticks
            int24 newTick = _nearest(BASE_TICK + displacements[d]);
            pool.movePriceToTick(newTick);
            
            // Measure total value before rebalance
            (uint256 w0, uint256 w1) = pool.getAmountsForLiquidity(
                pos.liquidity, pos.tickLower, pos.tickUpper
            );
            uint256 valueBefore = (w0 * _getPrice(newTick)) / 1e18 + w1;
            
            // Withdraw
            (w0, w1) = _withdrawPosition(pos);
            
            // Create new position centered on new tick
            int24 newLower = _nearest(newTick - RANGE_WIDTH / 2);
            int24 newUpper = _nearest(newTick + RANGE_WIDTH / 2);
            
            Position memory newPos = _createPosition(newLower, newUpper, w0, w1);
            
            // Measure value deployed in new position
            (uint256 a0, uint256 a1) = pool.getAmountsForLiquidity(
                newPos.liquidity, newPos.tickLower, newPos.tickUpper
            );
            uint256 valueAfter = (a0 * _getPrice(newTick)) / 1e18 + a1;
            
            // Residual = value NOT deployed (left as dust)
            uint256 residualUsd = valueBefore > valueAfter ? valueBefore - valueAfter : 0;
            // Also count token residuals directly
            uint256 dustToken0 = w0 > a0 ? w0 - a0 : 0;
            uint256 dustToken1 = w1 > a1 ? w1 - a1 : 0;
            uint256 dustUsd = (dustToken0 * _getPrice(newTick)) / 1e18 + dustToken1;
            
            console.log("Displacement +%d ticks:", uint256(int256(displacements[d])));
            console.log("  Value before: $%d, after: $%d", valueBefore / 1e6, valueAfter / 1e6);
            console.log("  Dust: %d token0 + %d token1 = $%d", dustToken0, dustToken1, dustUsd / 1e6);
            
            if (dustUsd < prevResidual && prevResidual > 0) {
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
    // Theorem 5 — Directional Asymmetry
    // For symmetric ±δ price moves, the up-move position retains strictly more
    // USD value than the down-move position (token1-denominated).
    // =========================================================================

    function test_theorem5_directionalAsymmetry() public {
        console.log("\n=== Theorem 5: Directional Asymmetry ===");
        console.log("Verifying: up-moves retain more value than symmetric down-moves");
        
        int24 tickLower = _nearest(BASE_TICK - RANGE_WIDTH / 2);
        int24 tickUpper = _nearest(BASE_TICK + RANGE_WIDTH / 2);
        
        uint256 deposit0 = 2 ether;
        uint256 deposit1 = 5000e6;
        
        uint256 asymmetryViolations = 0;
        
        int24[5] memory displacements = [int24(100), 200, 300, 400, 450];
        
        for (uint256 d = 0; d < displacements.length; d++) {
            int24 disp = displacements[d];
            
            // === UP MOVE ===
            _resetPool();
            token0Balance = 100 ether;
            token1Balance = 250_000e6;
            
            Position memory posUp = _createPosition(tickLower, tickUpper, deposit0, deposit1);
            
            // Record initial position value at initial price
            (uint256 init0, uint256 init1) = pool.getAmountsForLiquidity(
                posUp.liquidity, tickLower, tickUpper
            );
            uint256 initialValue = (init0 * _getPrice(BASE_TICK)) / 1e18 + init1;
            
            // Move UP
            int24 upTick = _nearest(BASE_TICK + disp);
            pool.movePriceToTick(upTick);
            
            // Withdraw at new price
            (uint256 upW0, uint256 upW1) = _withdrawPosition(posUp);
            uint256 upWithdrawnValue = (upW0 * _getPrice(upTick)) / 1e18 + upW1;
            
            // Create new position (value that can be deployed)
            int24 upNewLower = _nearest(upTick - RANGE_WIDTH / 2);
            int24 upNewUpper = _nearest(upTick + RANGE_WIDTH / 2);
            Position memory upNewPos = _createPosition(upNewLower, upNewUpper, upW0, upW1);
            (uint256 upA0, uint256 upA1) = pool.getAmountsForLiquidity(
                upNewPos.liquidity, upNewLower, upNewUpper
            );
            uint256 upDeployedValue = (upA0 * _getPrice(upTick)) / 1e18 + upA1;
            
            // === DOWN MOVE (symmetric) ===
            _resetPool();
            token0Balance = 100 ether;
            token1Balance = 250_000e6;
            
            Position memory posDown = _createPosition(tickLower, tickUpper, deposit0, deposit1);
            
            int24 downTick = _nearest(BASE_TICK - disp);
            pool.movePriceToTick(downTick);
            
            (uint256 downW0, uint256 downW1) = _withdrawPosition(posDown);
            uint256 downWithdrawnValue = (downW0 * _getPrice(downTick)) / 1e18 + downW1;
            
            int24 downNewLower = _nearest(downTick - RANGE_WIDTH / 2);
            int24 downNewUpper = _nearest(downTick + RANGE_WIDTH / 2);
            Position memory downNewPos = _createPosition(downNewLower, downNewUpper, downW0, downW1);
            (uint256 downA0, uint256 downA1) = pool.getAmountsForLiquidity(
                downNewPos.liquidity, downNewLower, downNewUpper
            );
            uint256 downDeployedValue = (downA0 * _getPrice(downTick)) / 1e18 + downA1;
            
            // Compute deployment efficiency: what % of withdrawn value was redeployed
            uint256 upEfficiency = upWithdrawnValue > 0 ? (upDeployedValue * 10000) / upWithdrawnValue : 0;
            uint256 downEfficiency = downWithdrawnValue > 0 ? (downDeployedValue * 10000) / downWithdrawnValue : 0;
            
            uint256 upDustUsd = upWithdrawnValue > upDeployedValue ? (upWithdrawnValue - upDeployedValue) / 1e6 : 0;
            uint256 downDustUsd = downWithdrawnValue > downDeployedValue ? (downWithdrawnValue - downDeployedValue) / 1e6 : 0;
            
            console.log("Displacement +/-%d ticks:", uint256(int256(disp)));
            console.log("  Initial value: $%d", initialValue / 1e6);
            console.log("  UP: withdrawn $%d, deployed $%d, dust $%d", 
                upWithdrawnValue / 1e6, upDeployedValue / 1e6, upDustUsd);
            console.log("  DN: withdrawn $%d, deployed $%d, dust $%d", 
                downWithdrawnValue / 1e6, downDeployedValue / 1e6, downDustUsd);
            
            // The up-move position should retain strictly more USD value than the
            // down-move position (Theorem 5, token1-denominated).
            if (upWithdrawnValue < downWithdrawnValue) {
                asymmetryViolations++;
                console.log("  VIOLATION: down-move retained more value!");
            } else {
                console.log("  UP - DN value gap: $%d", (upWithdrawnValue - downWithdrawnValue) / 1e6);
            }
        }
        
        assertEq(asymmetryViolations, 0, "Theorem 5: up-moves always retain more value");
        console.log("\nTheorem 5 verified: up-moves retain more value at all %d displacement levels", displacements.length);
    }
    
    // =========================================================================
    // Theorem 6 — Exit Asymmetry
    // For a (volatile, stablecoin) pool, a below-range exit retains less USD value
    // than an above-range exit at symmetric sqrt-price displacement past the boundary.
    // =========================================================================

    /// @notice Verifies Theorem 6 (Exit Asymmetry) from Geometric Siphon II §2.3.
    /// @dev The V3 amount equations treat token0 and token1 asymmetrically:
    ///        amount0 = L · (1/sqrtP_current − 1/sqrtP_upper)   — nonlinear in sqrtPrice
    ///        amount1 = L · (sqrtP_current − sqrtP_lower)       — linear in sqrtPrice
    ///
    ///      For (volatile token0, stablecoin token1):
    ///        - Below exit: position is 100% token0. The token0 quantity is governed
    ///          by the 1/sqrtPrice term, and its USD value falls as price falls.
    ///        - Above exit: position is 100% token1. The token1 quantity is governed
    ///          by the linear sqrtPrice term and its USD value is constant.
    ///
    ///      The test confirms two consequences at symmetric exit distances:
    ///        (a) the above-exit position retains strictly more USD value, and
    ///        (b) the below-exit position requires a larger swap fraction to redeploy.
    ///      Across 5 exit distances this produces 10 confirmations (5 value + 5 swap-frac).
    function test_theorem6_exitAsymmetry() public {
        console.log("\n=== Theorem 6: Exit Asymmetry ===");
        console.log("Verifying: below-exit retains less value and requires larger swaps");
        
        int24 tickLower = _nearest(BASE_TICK - RANGE_WIDTH / 2);
        int24 tickUpper = _nearest(BASE_TICK + RANGE_WIDTH / 2);
        
        uint256 deposit0 = 2 ether;
        uint256 deposit1 = 5000e6;
        
        int24[5] memory exitDistances = [int24(50), 100, 200, 300, 500];
        
        uint256 belowRetainsLess = 0;
        uint256 belowSwapsMore = 0;
        
        for (uint256 d = 0; d < exitDistances.length; d++) {
            int24 exitDist = exitDistances[d];
            
            // Create identical starting positions
            _resetPool();
            token0Balance = 100 ether;
            token1Balance = 250_000e6;
            Position memory posAbove = _createPosition(tickLower, tickUpper, deposit0, deposit1);
            uint128 startLiq = posAbove.liquidity;
            
            // Record initial value at initial price
            (uint256 init0, uint256 init1) = pool.getAmountsForLiquidity(startLiq, tickLower, tickUpper);
            uint256 initialValueUsd = (init0 * _getPrice(BASE_TICK)) / 1e18 + init1;
            
            // === ABOVE EXIT ===
            int24 aboveTick = tickUpper + exitDist;
            pool.movePriceToTick(aboveTick);
            (uint256 aboveW0, uint256 aboveW1) = pool.getAmountsForLiquidity(startLiq, tickLower, tickUpper);
            uint256 aboveValueUsd = (aboveW0 * _getPrice(aboveTick)) / 1e18 + aboveW1;
            
            // For a new in-range position centered on aboveTick, what fraction must be swapped?
            // Above exit: all USDC, need ~50% as WETH → swap fraction ≈ need0_value / total_value
            int24 aboveNewL = _nearest(aboveTick - RANGE_WIDTH / 2);
            int24 aboveNewU = _nearest(aboveTick + RANGE_WIDTH / 2);
            // At center of new range, the token ratio tells us the swap fraction
            // Use unit liquidity to get the ratio
            (uint256 ref0, uint256 ref1) = pool.getAmountsForLiquidity(1e12, aboveNewL, aboveNewU);
            uint256 refValue0 = (ref0 * _getPrice(aboveTick)) / 1e18;
            uint256 refValueTotal = refValue0 + ref1;
            // Above exit has all token1 → must swap refValue0/refValueTotal to get token0
            uint256 aboveSwapFracBps = refValueTotal > 0 ? (refValue0 * 10000) / refValueTotal : 0;
            
            // === BELOW EXIT ===
            _resetPool();
            int24 belowTick = tickLower - exitDist;
            pool.movePriceToTick(belowTick);
            (uint256 belowW0, uint256 belowW1) = pool.getAmountsForLiquidity(startLiq, tickLower, tickUpper);
            uint256 belowValueUsd = (belowW0 * _getPrice(belowTick)) / 1e18 + belowW1;
            
            // Below exit: all WETH, need ~50% as USDC → swap fraction ≈ need1_value / total_value
            int24 belowNewL = _nearest(belowTick - RANGE_WIDTH / 2);
            int24 belowNewU = _nearest(belowTick + RANGE_WIDTH / 2);
            (uint256 bRef0, uint256 bRef1) = pool.getAmountsForLiquidity(1e12, belowNewL, belowNewU);
            uint256 bRefValue0 = (bRef0 * _getPrice(belowTick)) / 1e18;
            uint256 bRefValueTotal = bRefValue0 + bRef1;
            // Below exit has all token0 → must swap bRef1/bRefValueTotal to get token1
            uint256 belowSwapFracBps = bRefValueTotal > 0 ? (bRef1 * 10000) / bRefValueTotal : 0;
            
            console.log("Exit +/-%d ticks:", uint256(int256(exitDist)));
            console.log("  Initial: $%d", initialValueUsd / 1e6);
            console.log("  ABOVE value: $%d, swap frac: %d bps", aboveValueUsd / 1e6, aboveSwapFracBps);
            console.log("  BELOW value: $%d, swap frac: %d bps", belowValueUsd / 1e6, belowSwapFracBps);
            
            // Check 1: below-exit retains less USD value
            if (aboveValueUsd > belowValueUsd) {
                belowRetainsLess++;
                uint256 gap = (aboveValueUsd - belowValueUsd);
                console.log("  Value gap: ABOVE > BELOW by $%d", gap / 1e6);
            }
            
            // Check 2: below-exit requires larger swap fraction
            if (belowSwapFracBps > aboveSwapFracBps) {
                belowSwapsMore++;
                console.log("  Swap gap: BELOW needs %d more bps", belowSwapFracBps - aboveSwapFracBps);
            }
        }
        
        console.log("\nBelow retains less value: %d / %d", belowRetainsLess, exitDistances.length);
        console.log("Below requires larger swap: %d / %d", belowSwapsMore, exitDistances.length);

        // Theorem 6 (Exit Asymmetry) — Paper II §2.3 reports "Verified with 10/10
        // Foundry confirmations". With 5 exit distances and 2 asymmetry checks
        // per distance (value retention + swap fraction), the suite produces
        // exactly 10 confirmations when the theorem holds at every level.
        uint256 totalConfirmations = belowRetainsLess + belowSwapsMore;
        assertEq(
            totalConfirmations,
            2 * exitDistances.length,
            "Theorem 6: below-exit must show both lower value retention and larger swap fraction at every distance"
        );
        console.log("Theorem 6 verified: %d / %d confirmations of below-exit asymmetry", totalConfirmations, 2 * exitDistances.length);
    }

    // =========================================================================
    // Helpers
    // =========================================================================
    
    function _resetPool() internal {
        pool.movePriceToTick(BASE_TICK);
    }
    
    function _nearest(int24 tick) internal pure returns (int24) {
        int24 compressed = tick / TICK_SPACING;
        if (tick < 0 && tick % TICK_SPACING != 0) compressed--;
        return compressed * TICK_SPACING;
    }
    
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
        if (amount0 > token0Balance) amount0 = token0Balance;
        if (amount1 > token1Balance) amount1 = token1Balance;
        token0Balance -= amount0;
        token1Balance -= amount1;
        pos = Position(tickLower, tickUpper, liquidity);
    }
    
    function _withdrawPosition(Position memory pos) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = pool.getAmountsForLiquidity(
            pos.liquidity, pos.tickLower, pos.tickUpper
        );
        token0Balance += amount0;
        token1Balance += amount1;
    }
    
    /// @notice Get price of token0 in token1 units (6 decimals) at a given tick
    function _getPrice(int24 _tick) internal pure returns (uint256) {
        // Linear approximation: price = 2500 * (1 + (tick - BASE_TICK) * 0.0001)
        int256 tickDelta = int256(_tick) - int256(BASE_TICK);
        int256 priceChange = int256(2500e6) * tickDelta / 10000;
        uint256 price = uint256(int256(2500e6) + priceChange);
        return price > 0 ? price : 1; // prevent division by zero
    }
}
