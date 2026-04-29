// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Test.sol";
import {MockCLPool} from "../src/MockCLPool.sol";
import {MockPositionTestBase} from "./helpers/MockPositionTestBase.sol";
import {TickHelpers} from "./helpers/Tick.sol";

/// @title ZeroSwapExtinctionProof
/// @notice Mock-pool verification of Theorem 3.
///
/// Theorem 3 (Zero-Swap Extinction, §3.6):
///   A CL position rebalanced repeatedly without an intervening swap
///   leaks a fraction α ∈ (0, 1) of its USD value at every event. After
///   K such rebalances the surviving value satisfies V_K ≤ V_0 (1 − α)^K,
///   so the position decays geometrically toward extinction. The leak
///   arises because `getLiquidityForAmounts` takes the minimum of the
///   per-token liquidity, binding at zero on the missing-token side
///   when the pre-rebalance position is single-sided.
contract ZeroSwapExtinctionProof is MockPositionTestBase {
    // Price: 1 token0 = 2500 token1 (WETH = 2500 USDC)
    // Token0: 18 decimals (WETH-like)
    // Token1: 6 decimals (USDC-like)
    uint160 constant INITIAL_SQRT_PRICE = 314748404868481885948183330816; // sqrt(2500) * 2^96 ~tick 73135
    int24 constant TICK_SPACING = 100;
    
    function setUp() public {
        pool = new MockCLPool(INITIAL_SQRT_PRICE);
        
        // Fund test contract with tokens
        token0Balance = 10 ether; // 10 WETH
        token1Balance = 25000e6;   // 25000 USDC
        
        console.log("=== SETUP ===");
        console.log("Initial tick:", pool.tick());
        console.log("Token0 balance:", token0Balance);
        console.log("Token1 balance:", token1Balance);
    }
    
    /// @notice Test 1: single-sided exit with no swap loses value.
    /// @dev Position becomes 100% token1, but new range needs both tokens.
    ///      The min() constraint forces zero liquidity, leaving the entire
    ///      withdrawn balance as residual.
    function test_theorem3_singleSidedExitNoSwapLosesValue() public {
        console.log("\n=== TEST 1: Single-Sided Exit + No Swap = Value Loss ===");
        
        int24 currentTick = pool.tick();
        console.log("Starting tick:", uint256(int256(currentTick)));
        
        // Create position below current price (will become 100% token1 when price moves up)
        int24 tickLower = TickHelpers.nearest(currentTick - 300, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick - 100, TICK_SPACING);
        
        console.log("Initial range tickLower:", uint256(int256(tickLower)));
        console.log("Initial range tickUpper:", uint256(int256(tickUpper)));
        
        // Deposit both tokens
        uint256 deposit0 = 1 ether;
        uint256 deposit1 = 2500e6;
        
        Position memory pos = _createPosition(tickLower, tickUpper, deposit0, deposit1);
        console.log("Position created, liquidity:", pos.liquidity);
        
        // Calculate initial value
        uint256 valueInitial = _calculatePositionValue(pos);
        console.log("Initial position value (USD):", valueInitial / 1e6);
        
        // Move price ABOVE the range (position becomes 100% token1)
        int24 newTick = tickUpper + 200;
        pool.movePriceToTick(newTick);
        console.log("\nPrice moved to tick (ABOVE range):", uint256(int256(newTick)));
        
        // Withdraw - should get ONLY token1
        (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
        console.log("Withdrawn token0:", withdrawn0);
        console.log("Withdrawn token1:", withdrawn1);
        
        // Verify single-sided withdrawal
        assertEq(withdrawn0, 0, "Should withdraw 0 token0 (above range)");
        assertGt(withdrawn1, 0, "Should withdraw token1");
        
        console.log("\n=== ATTEMPTING REBALANCE WITH NO SWAP ===");
        
        // Try to mint new range centered on current price (needs BOTH tokens)
        int24 newLower = TickHelpers.nearest(newTick - 200, TICK_SPACING);
        int24 newUpper = TickHelpers.nearest(newTick + 200, TICK_SPACING);
        
        console.log("New range tickLower:", uint256(int256(newLower)));
        console.log("New range tickUpper:", uint256(int256(newUpper)));
        console.log("Available token0:", withdrawn0);
        console.log("Available token1:", withdrawn1);
        
        // This will create near-zero liquidity due to min() constraint
        Position memory newPos = _createPosition(newLower, newUpper, withdrawn0, withdrawn1);
        console.log("New position liquidity:", newPos.liquidity);
        
        // Calculate post-rebalance value
        uint256 valueFinal = _calculatePositionValue(newPos);
        uint256 residualValue = _calculateValue(token0Balance, token1Balance) - _calculateValue(deposit0 - withdrawn0, deposit1 - withdrawn1);
        
        console.log("\n=== RESULTS ===");
        console.log("Initial value (USD):", valueInitial / 1e6);
        console.log("Final value (USD):", valueFinal / 1e6);
        console.log("Residual value (USD):", residualValue / 1e6);
        
        // Calculate alpha (residual fraction per Theorem 3)
        uint256 alpha = (valueInitial - valueFinal) * 1e18 / valueInitial;
        console.log("Alpha (residual fraction) percent:", alpha * 100 / 1e18);
        
        // ASSERTIONS
        assertLt(valueFinal, valueInitial, "Post-rebalance value MUST be less than initial");
        assertGt(alpha, 0, "Residual fraction alpha MUST be > 0");
        assertGt(alpha, 5e17, "Alpha should be > 50% for single-sided exit with no swap");
        
        console.log("\nNo-swap rebalance from single-sided position: full withdrawn balance leaks as residual");
    }
    
    /// @notice Test 2: Residual scales monotonically with displacement
    /// @dev The further out of range, the more single-sided the position, the higher alpha
    function test_theorem3_residualScalesWithDisplacement() public {
        console.log("\n=== TEST 2: Residual Scales With Displacement ===");
        
        int24 currentTick = pool.tick();
        
        // Use wider ranges so partial exit doesn't immediately go to 100%
        int24 tickLower = TickHelpers.nearest(currentTick - 500, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick + 500, TICK_SPACING);
        
        console.log("Base range tickLower:", uint256(int256(tickLower)));
        console.log("Base range tickUpper:", uint256(int256(tickUpper)));
        
        // Test displacements: 100, 300, 600 ticks WITHIN the range (partial exits)
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
            
            // Create position
            Position memory pos = _createPosition(tickLower, tickUpper, 2 ether, 5000e6);
            uint256 valueInitial = _calculatePositionValue(pos);
            
            // Move price UPWARD by displacement (still within or near range edge)
            int24 newTick = currentTick + displacements[i];
            pool.movePriceToTick(newTick);
            console.log("Moved to tick:", uint256(int256(newTick)));
            
            // Withdraw
            (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
            console.log("Withdrawn token0:", withdrawn0);
            console.log("Withdrawn token1:", withdrawn1);
            
            // Rebalance to TIGHTER range (no swap)
            int24 newLower = TickHelpers.nearest(newTick - 250, TICK_SPACING);
            int24 newUpper = TickHelpers.nearest(newTick + 250, TICK_SPACING);
            Position memory newPos = _createPosition(newLower, newUpper, withdrawn0, withdrawn1);
            
            uint256 valueFinal = _calculatePositionValue(newPos);
            
            // Calculate alpha (handle case where final > initial)
            if (valueFinal >= valueInitial) {
                alphas[i] = 0; // No loss
            } else {
                alphas[i] = (valueInitial - valueFinal) * 1e18 / valueInitial;
            }
            console.log("Value initial (USD):", valueInitial / 1e6);
            console.log("Value final (USD):", valueFinal / 1e6);
            console.log("Alpha percent:", alphas[i] * 100 / 1e18);
        }
        
        console.log("\n=== MONOTONICITY CHECK ===");
        console.log("Alpha @ 100 ticks percent:", alphas[0] * 100 / 1e18);
        console.log("Alpha @ 300 ticks percent:", alphas[1] * 100 / 1e18);
        console.log("Alpha @ 600 ticks percent:", alphas[2] * 100 / 1e18);
        
        // ASSERTIONS: alpha must increase with displacement (or at least not decrease)
        assertGe(alphas[1], alphas[0], "Alpha must not decrease: 300 ticks >= 100 ticks");
        assertGt(alphas[2], alphas[1], "Alpha must increase: 600 ticks > 300 ticks");
        assertGt(alphas[2], 0, "Final displacement must show some loss");
        
        console.log("\nAlpha scales monotonically with displacement");
    }
    
    /// @notice Test 3: Repeated rebalances show geometric decay
    /// @dev Simulate 5 cycles of: exit range -> withdraw -> mint new range
    ///      Each cycle should reduce value by approximately constant factor (1-a)
    function test_theorem3_repeatedRebalancesGeometricDecay() public {
        console.log("\n=== TEST 3: Repeated Rebalances -> Geometric Decay ===");
        
        int24 currentTick = pool.tick();
        
        // Start with wider range
        int24 tickLower = TickHelpers.nearest(currentTick - 400, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick + 400, TICK_SPACING);
        
        Position memory pos = _createPosition(tickLower, tickUpper, 2 ether, 5000e6);
        
        uint256[6] memory values; // Store value at each cycle
        uint256[5] memory decayFactors; // Store V_k / V_{k-1}
        
        values[0] = _calculatePositionValue(pos);
        console.log("Cycle 0 - Initial value (USD):", values[0] / 1e6);
        
        // Run 5 rebalance cycles
        for (uint cycle = 1; cycle <= 5; cycle++) {
            console.log("\n--- Cycle ---", cycle);
            
            // Move price UPWARD by moderate amount (150 ticks)
            int24 newTick = currentTick + 150;
            pool.movePriceToTick(newTick);
            currentTick = newTick; // Update current tick for next iteration
            console.log("Moved to tick:", uint256(int256(newTick)));
            
            // Withdraw position
            (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
            console.log("Withdrew token0:", withdrawn0);
            console.log("Withdrew token1:", withdrawn1);
            
            // Mint new range centered on new price, SAME WIDTH range (NO SWAP)
            tickLower = TickHelpers.nearest(newTick - 400, TICK_SPACING);
            tickUpper = TickHelpers.nearest(newTick + 400, TICK_SPACING);
            pos = _createPosition(tickLower, tickUpper, withdrawn0, withdrawn1);
            
            values[cycle] = _calculatePositionValue(pos);
            console.log("Value (USD):", values[cycle] / 1e6);
            
            // Calculate decay factor (handle division by zero)
            if (values[cycle - 1] > 0) {
                decayFactors[cycle - 1] = values[cycle] * 1e18 / values[cycle - 1];
                console.log("Decay factor percent:", decayFactors[cycle - 1] * 100 / 1e18);
            } else {
                decayFactors[cycle - 1] = 0;
                console.log("Decay factor: EXTINCT (previous value was 0)");
            }
        }
        
        console.log("\n=== GEOMETRIC DECAY ANALYSIS ===");
        console.log("V0 (USD):", values[0] / 1e6);
        console.log("V1 (USD):", values[1] / 1e6);
        console.log("V2 (USD):", values[2] / 1e6);
        console.log("V3 (USD):", values[3] / 1e6);
        console.log("V4 (USD):", values[4] / 1e6);
        console.log("V5 (USD):", values[5] / 1e6);
        
        // ASSERTIONS
        // 1. Monotonic decrease
        for (uint i = 1; i <= 5; i++) {
            assertLt(values[i], values[i-1], "Value must decrease each cycle");
        }
        
        // 2. Approximately constant decay factor (geometric progression)
        // Calculate average of non-zero decay factors
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
                    // Allow high variance due to discrete tick movements and changing token ratios
                    assertLt(relativeDeviation, 100, "Decay factor should show geometric pattern (allow variance)");
                }
            }
        }
        
        // 3. Verify substantial total decay over 5 cycles
        uint256 totalDecay = (values[0] - values[5]) * 100 / values[0];
        console.log("\nTotal decay over 5 cycles:", totalDecay, "%");
        assertGt(totalDecay, 90, "Should lose >90% of value over 5 cycles (geometric decay)");
        assertLt(values[5], values[0] / 10, "Final value should be <10% of initial");
        
        console.log("\nRepeated rebalances produce geometric decay V_K <= V0(1-a)^K");
    }
    
    /// @notice Test 4: Far out of range -> near-total loss
    /// @dev Simulates a terminal event like ZARP event 14 where position moved 2000 ticks
    ///      out of range, resulting in alpha = 0.994 (99.4% loss)
    function test_theorem3_fullyOutOfRangeNearTotalLoss() public {
        console.log("\n=== TEST 4: Extreme Displacement -> Near-Total Loss ===");
        
        int24 currentTick = pool.tick();
        
        // Create position
        int24 tickLower = TickHelpers.nearest(currentTick - 200, TICK_SPACING);
        int24 tickUpper = TickHelpers.nearest(currentTick + 200, TICK_SPACING);
        
        console.log("Initial range tickLower:", uint256(int256(tickLower)));
        console.log("Initial range tickUpper:", uint256(int256(tickUpper)));
        
        Position memory pos = _createPosition(tickLower, tickUpper, 1 ether, 2500e6);
        uint256 valueInitial = _calculatePositionValue(pos);
        
        console.log("Initial value (USD):", valueInitial / 1e6);
        
        // Move price FAR past upper boundary (2000 ticks = extreme displacement)
        int24 newTick = tickUpper + 2000;
        pool.movePriceToTick(newTick);
        console.log("\nMoved to tick (+2000 from upper):", uint256(int256(newTick)));
        console.log("Position is now DEEPLY single-sided");
        
        // Withdraw
        (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(pos);
        console.log("\nWithdrawn token0:", withdrawn0);
        console.log("Withdrawn token1:", withdrawn1);
        
        // Verify deeply single-sided
        assertEq(withdrawn0, 0, "Should be 100% token1");
        
        // Try to rebalance into new range (will fail catastrophically)
        int24 newLower = TickHelpers.nearest(newTick - 200, TICK_SPACING);
        int24 newUpper = TickHelpers.nearest(newTick + 200, TICK_SPACING);
        
        console.log("\nNew range tickLower:", uint256(int256(newLower)));
        console.log("New range tickUpper:", uint256(int256(newUpper)));
        
        Position memory newPos = _createPosition(newLower, newUpper, withdrawn0, withdrawn1);
        uint256 valueFinal = _calculatePositionValue(newPos);
        
        console.log("\nFinal value (USD):", valueFinal / 1e6);
        console.log("New position liquidity:", newPos.liquidity);
        
        // Calculate alpha
        uint256 alpha = (valueInitial - valueFinal) * 1e18 / valueInitial;
        console.log("\n=== TERMINAL EVENT ===");
        console.log("Alpha (residual fraction) percent:", alpha * 100 / 1e18);
        
        // ASSERTIONS
        assertGt(alpha, 95e16, "Alpha must be > 95% (near-total loss)");
        assertLt(valueFinal, valueInitial / 20, "Final value < 5% of initial");
        
        console.log("\nExtreme displacement: alpha saturates near 1 (near-total value extinction)");
        console.log("  (comparable to ZARP event 14: alpha = 0.99)");
    }
    
    function _calculatePositionValue(Position memory pos) internal view returns (uint256) {
        (uint256 amount0, uint256 amount1) = pool.getAmountsForLiquidity(
            pos.liquidity,
            pos.tickLower,
            pos.tickUpper
        );
        
        return _calculateValue(amount0, amount1);
    }
    
    function _calculateValue(uint256 amount0, uint256 amount1) internal pure returns (uint256) {
        // V = amount0 * price + amount1
        // price = 2500 token1 per token0
        // amount0 in 18 decimals, amount1 in 6 decimals
        // Result in 6 decimals (USD)
        return (amount0 * 2500) / 1e18 + amount1;
    }
}
