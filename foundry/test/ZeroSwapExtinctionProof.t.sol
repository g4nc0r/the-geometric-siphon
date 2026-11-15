// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Test.sol";
import {MockCLPool} from "../src/MockCLPool.sol";
import {MockPositionTestBase} from "./helpers/MockPositionTestBase.sol";
import {TickHelpers} from "./helpers/Tick.sol";

/// @title ZeroSwapExtinctionProof
/// @notice Mock-pool verification of Theorem 3.
///
/// Theorem 3 (zero-swap extinction, §3.6):
///   A position rebalanced with no swap after the price has left its range
///   redeploys a fraction 1 − α of its value, with α > 0. After K such
///   rebalances V_K = V_0 ∏ (1 − α_k), so the value decays geometrically.
///   The loss arises because `getLiquidityForAmounts` takes the minimum of
///   the per-token liquidities.
contract ZeroSwapExtinctionProof is MockPositionTestBase {
    // The pool has no decimal offset. Values are in token1 at the pool's own price.
    uint160 constant INITIAL_SQRT_PRICE = 314748404868481885948183330816; // the pool's anchor, tick 73135
    int24 constant TICK_SPACING = 100;
    
    function setUp() public {
        pool = new MockCLPool(INITIAL_SQRT_PRICE);
        
        token0Balance = 10 ether; // 10 WETH
        token1Balance = 25000e6;   // 25000 USDC
        
        console.log("Setup");
        console.log("Initial tick:", pool.tick());
        console.log("Token0 balance:", token0Balance);
        console.log("Token1 balance:", token1Balance);
    }
    
    /// @notice Test 4: single-sided exit with no swap loses value.
    /// @dev The position holds token1 only and the new range needs both tokens,
    ///      so the mint minimum gives zero liquidity and the whole withdrawn
    ///      balance is left as residual.
    function test_theorem3_singleSidedExitNoSwapLosesValue() public {
        console.log("\nTest 4: single-sided exit with no swap");
        
        int24 currentTick = pool.tick();
        console.log("Starting tick:", uint256(int256(currentTick)));
        
        // Position below the current price, so it holds token1 only
        int24 tickLower = TickHelpers.nearest(currentTick - 300, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick - 100, TICK_SPACING);
        
        console.log("Initial range tickLower:", uint256(int256(tickLower)));
        console.log("Initial range tickUpper:", uint256(int256(tickUpper)));
        
        uint256 deposit0 = 1 ether;
        uint256 deposit1 = 2500e6;
        
        Position memory pos = _createPosition(tickLower, tickUpper, deposit0, deposit1);
        console.log("Position created, liquidity:", pos.liquidity);
        
        uint256 valueInitial = _calculatePositionValue(pos);
        console.log("Initial position value (USD):", valueInitial / 1e6);
        
        // Move the price to 200 ticks above the range
        int24 newTick = tickUpper + 200;
        pool.movePriceToTick(newTick);
        console.log("\nPrice moved to tick (above range):", uint256(int256(newTick)));
        
        // The withdrawal returns token1 only
        (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
        console.log("Withdrawn token0:", withdrawn0);
        console.log("Withdrawn token1:", withdrawn1);
        
        assertEq(withdrawn0, 0, "Should withdraw 0 token0 (above range)");
        assertGt(withdrawn1, 0, "Should withdraw token1");
        
        console.log("\nRebalance with no swap");
        
        // Mint into a range around the current price, which needs both tokens
        int24 newLower = TickHelpers.nearest(newTick - 200, TICK_SPACING);
        int24 newUpper = TickHelpers.nearest(newTick + 200, TICK_SPACING);
        
        console.log("New range tickLower:", uint256(int256(newLower)));
        console.log("New range tickUpper:", uint256(int256(newUpper)));
        console.log("Available token0:", withdrawn0);
        console.log("Available token1:", withdrawn1);
        
        // The mint minimum gives zero liquidity
        Position memory newPos = _createPosition(newLower, newUpper, withdrawn0, withdrawn1);
        console.log("New position liquidity:", newPos.liquidity);
        
        uint256 valueFinal = _calculatePositionValue(newPos);
        uint256 residualValue = valueInitial - valueFinal;
        
        console.log("\nResults");
        console.log("Initial value (USD):", valueInitial / 1e6);
        console.log("Final value (USD):", valueFinal / 1e6);
        console.log("Residual value (USD):", residualValue / 1e6);
        
        // Residual fraction
        uint256 alpha = (valueInitial - valueFinal) * 1e18 / valueInitial;
        console.log("Alpha (residual fraction) percent:", alpha * 100 / 1e18);
        
        assertLt(valueFinal, valueInitial, "Post-rebalance value must be less than initial");
        assertGt(alpha, 0, "Residual fraction alpha must be > 0");
        assertGt(alpha, 5e17, "Alpha should be > 50% for single-sided exit with no swap");
        
    }
    
    /// @notice Test 5: the residual fraction grows with displacement.
    /// @dev Displacements of 100 and 300 ticks stay inside the old range; 600 ticks is an exit.
    function test_theorem3_residualScalesWithDisplacement() public {
        console.log("\nTest 5: residual scales with displacement");
        
        int24 currentTick = pool.tick();
        
        int24 tickLower = TickHelpers.nearest(currentTick - 500, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick + 500, TICK_SPACING);
        
        console.log("Base range tickLower:", uint256(int256(tickLower)));
        console.log("Base range tickUpper:", uint256(int256(tickUpper)));
        
        int24[3] memory displacements = [int24(100), int24(300), int24(600)];
        uint256[3] memory alphas;

        uint256 snap = vm.snapshotState();

        for (uint i = 0; i < 3; i++) {
            vm.revertToState(snap);
            snap = vm.snapshotState();
            currentTick = pool.tick();
            tickLower = TickHelpers.nearest(currentTick - 500, TICK_SPACING);
            tickUpper = TickHelpers.nearest(currentTick + 500, TICK_SPACING);
            
            console.log("\n--- Displacement (ticks):", uint256(int256(displacements[i])));
            
            Position memory pos = _createPosition(tickLower, tickUpper, 2 ether, 5000e6);
            
            // Move the price up (inside the range at 100 and 300, an exit at 600)
            int24 newTick = currentTick + displacements[i];
            pool.movePriceToTick(newTick);
            console.log("Moved to tick:", uint256(int256(newTick)));

            // Value withdrawn, at the price of the rebalance
            uint256 valueInitial = _calculatePositionValue(pos);
            
            (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
            console.log("Withdrawn token0:", withdrawn0);
            console.log("Withdrawn token1:", withdrawn1);
            
            // Rebalance into a 500-tick range with no swap
            int24 newLower = TickHelpers.nearest(newTick - 250, TICK_SPACING);
            int24 newUpper = TickHelpers.nearest(newTick + 250, TICK_SPACING);
            Position memory newPos = _createPosition(newLower, newUpper, withdrawn0, withdrawn1);
            
            uint256 valueFinal = _calculatePositionValue(newPos);
            
            // alpha is zero where nothing is lost
            if (valueFinal >= valueInitial) {
                alphas[i] = 0; // No loss
            } else {
                alphas[i] = (valueInitial - valueFinal) * 1e18 / valueInitial;
            }
            console.log("Value initial (USD):", valueInitial / 1e6);
            console.log("Value final (USD):", valueFinal / 1e6);
            console.log("Alpha (bps):", alphas[i] * 10000 / 1e18);
        }
        
        console.log("Alpha @ 100 ticks percent:", alphas[0] * 100 / 1e18);
        console.log("Alpha @ 300 ticks percent:", alphas[1] * 100 / 1e18);
        console.log("Alpha @ 600 ticks percent:", alphas[2] * 100 / 1e18);
        
        // ASSERTIONS: alpha is positive and increases with displacement
        assertGt(alphas[0], 0, "Alpha must be positive at 100 ticks");
        assertGt(alphas[1], alphas[0], "Alpha must increase: 300 ticks > 100 ticks");
        assertGt(alphas[2], alphas[1], "Alpha must increase: 600 ticks > 300 ticks");
        assertGt(alphas[2], 0, "Final displacement must show some loss");
        
    }
    
    /// @notice Test 6: repeated rebalances with no swap decay geometrically.
    /// @dev Five cycles of an upward drift, a withdrawal, and a re-mint into a
    ///      range of the same width. Each cycle redeploys a fraction 1 − α_k.
    function test_theorem3_repeatedRebalancesGeometricDecay() public {
        console.log("\nTest 6: repeated rebalances with no swap");
        
        int24 currentTick = pool.tick();
        
        int24 tickLower = TickHelpers.nearest(currentTick - 400, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick + 400, TICK_SPACING);
        
        Position memory pos = _createPosition(tickLower, tickUpper, 2 ether, 5000e6);
        
        uint256[6] memory values; // Store value at each cycle
        uint256[5] memory decayFactors; // Store V_k / V_{k-1}
        
        values[0] = _calculatePositionValue(pos);
        console.log("Cycle 0 - Initial value (USD):", values[0] / 1e6);
        
        for (uint cycle = 1; cycle <= 5; cycle++) {
            console.log("\n--- Cycle ---", cycle);
            
            // Move the price up 150 ticks
            int24 newTick = currentTick + 150;
            pool.movePriceToTick(newTick);
            currentTick = newTick; // Update current tick for next iteration
            console.log("Moved to tick:", uint256(int256(newTick)));
            
            (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
            console.log("Withdrew token0:", withdrawn0);
            console.log("Withdrew token1:", withdrawn1);
            uint256 valueWithdrawn = _calculateValue(withdrawn0, withdrawn1);
            
            // Mint into a range of the same width around the new price, with no swap
            tickLower = TickHelpers.nearest(newTick - 400, TICK_SPACING);
            tickUpper = TickHelpers.nearest(newTick + 400, TICK_SPACING);
            pos = _createPosition(tickLower, tickUpper, withdrawn0, withdrawn1);
            
            values[cycle] = _calculatePositionValue(pos);
            console.log("Value (USD):", values[cycle] / 1e6);
            
            // Decay factor of this cycle
            if (valueWithdrawn > 0) {
                // 1 - alpha_k: value redeployed over value withdrawn, at the same price
                decayFactors[cycle - 1] = values[cycle] * 1e18 / valueWithdrawn;
                console.log("Decay factor (bps):", decayFactors[cycle - 1] * 10000 / 1e18);
            } else {
                decayFactors[cycle - 1] = 0;
                console.log("Decay factor: undefined (nothing withdrawn)");
            }
        }
        
        console.log("\nValues by cycle");
        console.log("V0 (USD):", values[0] / 1e6);
        console.log("V1 (USD):", values[1] / 1e6);
        console.log("V2 (USD):", values[2] / 1e6);
        console.log("V3 (USD):", values[3] / 1e6);
        console.log("V4 (USD):", values[4] / 1e6);
        console.log("V5 (USD):", values[5] / 1e6);
        
        for (uint i = 1; i <= 5; i++) {
            assertLt(values[i], values[i-1], "Value must decrease each cycle");
        }
        
        // The decay factors stay within a wide band of their mean
        uint256 sumDecay = 0;
        uint256 countNonZero = 0;
        for (uint i = 0; i < 5; i++) {
            if (decayFactors[i] > 0) {
                sumDecay += decayFactors[i];
                countNonZero++;
            }
        }
        
        if (countNonZero > 1) {
            uint256 avgDecayFactor = sumDecay / countNonZero;
            console.log("\nAverage decay factor percent:", avgDecayFactor * 100 / 1e18);
            
            for (uint i = 0; i < 5; i++) {
                if (decayFactors[i] > 0) {
                    uint256 deviation = decayFactors[i] > avgDecayFactor 
                        ? decayFactors[i] - avgDecayFactor 
                        : avgDecayFactor - decayFactors[i];
                    uint256 relativeDeviation = deviation * 100 / avgDecayFactor;
                    
                    console.log("Cycle deviation percent:", i+1);
                    console.log("  Relative deviation:", relativeDeviation);
                    // The two alternating factors differ, so the tolerance is wide
                    assertLt(relativeDeviation, 100, "Decay factor within the band of its mean");
                }
            }
        }
        
        // Total decay over five cycles
        uint256 totalDecay = (values[0] - values[5]) * 100 / values[0];
        console.log("\nTotal decay over 5 cycles:", totalDecay, "%");
        assertGt(totalDecay, 90, "Should lose >90% of value over 5 cycles (geometric decay)");
        assertLt(values[5], values[0] / 10, "Final value should be <10% of initial");
        
    }
    
    /// @notice Test 7: far out of range, the loss is total.
    /// @dev The price is taken 2,000 ticks past the upper bound.
    function test_theorem3_fullyOutOfRangeNearTotalLoss() public {
        console.log("\nTest 7: extreme displacement");
        
        int24 currentTick = pool.tick();
        
        int24 tickLower = TickHelpers.nearest(currentTick - 200, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick + 200, TICK_SPACING);
        
        console.log("Initial range tickLower:", uint256(int256(tickLower)));
        console.log("Initial range tickUpper:", uint256(int256(tickUpper)));
        
        Position memory pos = _createPosition(tickLower, tickUpper, 1 ether, 2500e6);
        uint256 valueInitial = _calculatePositionValue(pos);
        
        console.log("Initial value (USD):", valueInitial / 1e6);
        
        // Move the price 2,000 ticks past the upper bound
        int24 newTick = tickUpper + 2000;
        pool.movePriceToTick(newTick);
        console.log("\nMoved to tick (+2000 from upper):", uint256(int256(newTick)));
        
        (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
        console.log("\nWithdrawn token0:", withdrawn0);
        console.log("Withdrawn token1:", withdrawn1);
        
        assertEq(withdrawn0, 0, "Should be 100% token1");
        
        // Mint into a new range around the price
        int24 newLower = TickHelpers.nearest(newTick - 200, TICK_SPACING);
        int24 newUpper = TickHelpers.nearest(newTick + 200, TICK_SPACING);
        
        console.log("\nNew range tickLower:", uint256(int256(newLower)));
        console.log("New range tickUpper:", uint256(int256(newUpper)));
        
        Position memory newPos = _createPosition(newLower, newUpper, withdrawn0, withdrawn1);
        uint256 valueFinal = _calculatePositionValue(newPos);
        
        console.log("\nFinal value (USD):", valueFinal / 1e6);
        console.log("New position liquidity:", newPos.liquidity);
        
        uint256 alpha = (valueInitial - valueFinal) * 1e18 / valueInitial;
        console.log("Alpha (residual fraction) percent:", alpha * 100 / 1e18);
        
        assertGt(alpha, 95e16, "Alpha must be > 95% (near-total loss)");
        assertLt(valueFinal, valueInitial / 20, "Final value < 5% of initial");
        
    }
    
    function _calculatePositionValue(Position memory pos) internal view returns (uint256) {
        (uint256 amount0, uint256 amount1) = pool.getAmountsForLiquidity(
            pos.liquidity,
            pos.tickLower,
            pos.tickUpper
        );
        
        return _calculateValue(amount0, amount1);
    }
    
    function _calculateValue(uint256 amount0, uint256 amount1) internal view returns (uint256) {
        // Value in token1 units at the pool's current price.
        return _valueAtPoolPrice(amount0, amount1);
    }
}
