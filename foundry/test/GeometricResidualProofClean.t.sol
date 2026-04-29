// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/Test.sol";
import {MockCLPool} from "../src/MockCLPool.sol";
import {MockPositionTestBase} from "./helpers/MockPositionTestBase.sol";
import {TickHelpers} from "./helpers/Tick.sol";

/// @title GeometricResidualProofClean
/// @notice Mock-pool verification of Theorem 1.
///
/// Theorem 1 (Geometric Residual Existence, §3.4):
///   For a CL position rebalanced to a new tick range while the V3 amount
///   equations require a different token ratio at the new range, the
///   rebalance produces a strictly positive geometric residual ΔR > 0.
///   The residual vanishes if and only if the token ratio is preserved
///   (e.g. a same-range rebalance after price displacement).
///
/// @dev Uses the linear-tick-math `MockCLPool` for fast, network-free
///      regression. Quantitative cross-checks against exact V3 TickMath
///      are in `GeometricResidualProof` (live fork).
contract GeometricResidualProofClean is MockPositionTestBase {
    Position position1;

    // Price assumption: 1 token0 = 2500 token1 (like WETH = 2500 USDC)
    // sqrtPrice = sqrt(2500) * 2^96 = 3968.5... * 2^96
    uint160 constant INITIAL_SQRT_PRICE = 314748404868481885948183330816; // ~tick 73135

    // Same-range integer-rounding noise floors:
    //   1e12 wei  ≈ 1 nano-WETH  ≈ $0.0000025 at $2500/WETH
    //   1e3  units ≈ 0.001 USDC  ≈ $0.001
    uint256 constant SAME_RANGE_TOKEN0_TOLERANCE = 1e12;
    uint256 constant SAME_RANGE_TOKEN1_TOLERANCE = 1e3;
    
    function setUp() public {
        pool = new MockCLPool(INITIAL_SQRT_PRICE);
        
        // Fund test contract with tokens
        token0Balance = 10 ether; // 10 "WETH"
        token1Balance = 25000e6;   // 25000 "USDC" (6 decimals)
        
        console.log("=== SETUP ===");
        console.log("Initial price tick:", pool.tick());
        console.log("Token0 balance:", token0Balance);
        console.log("Token1 balance:", token1Balance);
    }
    
    /// @notice Test 1: Range change creates measurable residual
    function test_theorem1_rangeChangeCreatesResidual() public {
        console.log("\n=== TEST 1: Range Change Creates Residual ===");
        
        int24 currentTick = pool.tick();
        console.log("Current tick:", uint256(int256(currentTick)));
        
        // Create position 1: narrow range (500 ticks around current)
        int24 tickLower1 = TickHelpers.nearest(currentTick - 500, 100);
        int24 tickUpper1 = TickHelpers.nearest(currentTick + 500, 100);
        
        // Deposit 1 token0 + whatever token1 needed
        uint256 deposit0 = 1 ether;
        uint256 deposit1 = 2500e6;
        
        position1 = _createPosition(tickLower1, tickUpper1, deposit0, deposit1);
        console.log("Position 1 created: liquidity =", position1.liquidity);
        // Position 1 range logged
        
        // Simulate price movement (move up 200 ticks)
        int24 newTick = currentTick + 200;
        pool.movePriceToTick(newTick);
        console.log("Price moved to tick:", uint256(int256(newTick)));
        
        // Save balances before rebalance
        uint256 balance0Before = token0Balance;
        uint256 balance1Before = token1Balance;
        
        // Rebalance position 1: withdraw from old range, deposit into WIDER range
        int24 tickLower2 = TickHelpers.nearest(newTick - 1000, 100);
        int24 tickUpper2 = TickHelpers.nearest(newTick + 1000, 100);
        
        console.log("\n--- Rebalancing Position 1 ---");
        // Old range logged
        // New range logged
        
        (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(position1);
        console.log("Withdrawn token0:", withdrawn0);
        console.log("Withdrawn token1:", withdrawn1);
        
        position1 = _createPosition(tickLower2, tickUpper2, withdrawn0, withdrawn1);
        console.log("Re-deposited: liquidity =", position1.liquidity);
        
        // Measure residual
        uint256 residual0 = token0Balance - balance0Before;
        uint256 residual1 = token1Balance - balance1Before;
        
        console.log("\n=== RESIDUAL CREATED ===");
        console.log("Token0 residual:", residual0);
        console.log("Token1 residual:", residual1);
        console.log("Residual USD (@ $2500/token0):", (residual0 * 2500) / 1e18 + residual1 / 1e6);
        
        // PROOF: Residual must exist
        assertTrue(residual0 > 0 || residual1 > 0, "Geometric residual MUST exist after range change");
        assertGt(residual0 + residual1, 0, "Total residual > 0");
    }
    
    /// @notice Test 2: Same range = zero residual (control)
    function test_theorem1_noRangeChange_noResidual() public {
        console.log("\n=== TEST 2: Same Range = No Residual (Control) ===");
        
        int24 currentTick = pool.tick();
        int24 tickLower = TickHelpers.nearest(currentTick - 500, 100);
        int24 tickUpper = TickHelpers.nearest(currentTick + 500, 100);
        
        position1 = _createPosition(tickLower, tickUpper, 1 ether, 2500e6);
        
        // Move price
        pool.movePriceToTick(currentTick + 200);
        
        uint256 balance0Before = token0Balance;
        uint256 balance1Before = token1Balance;
        
        // Rebalance to SAME range
        (uint256 withdrawn0, uint256 withdrawn1) = _withdrawPosition(position1);
        position1 = _createPosition(tickLower, tickUpper, withdrawn0, withdrawn1);
        
        uint256 residual0 = token0Balance > balance0Before ? token0Balance - balance0Before : 0;
        uint256 residual1 = token1Balance > balance1Before ? token1Balance - balance1Before : 0;
        
        console.log("Token0 residual:", residual0);
        console.log("Token1 residual:", residual1);
        
        // PROOF: Same range should have minimal/zero residual
        assertLt(residual0, SAME_RANGE_TOKEN0_TOLERANCE, "Same range -> minimal token0 residual");
        assertLt(residual1, SAME_RANGE_TOKEN1_TOLERANCE, "Same range -> minimal token1 residual");
    }
    
    /// @notice Stage-2 dust absorption is not verified on this mock: the linear
    ///         pool does not implement the shared-liquidity / fee-accounting
    ///         that absorption requires. The architectural precondition is
    ///         instead verified on a stock NFPM in the fork test
    ///         `GeometricResidualProof.test_section7_1_stockNfpmDoesNotAbsorbDust`,
    ///         which asserts the inverse claim (no cross-position absorption
    ///         on a vault-per-pool design); see paper §7.1.
    
    /// @notice Theorem 1: residual scales with position size.
    function test_theorem1_largerPositionLargerResidual() public {
        uint256 snap = vm.snapshotState();

        uint256 smallResidual = _measureResidual(0.5 ether, 1250e6);
        console.log("Small position residual (raw sum):", smallResidual);

        vm.revertToState(snap);

        uint256 largeResidual = _measureResidual(2 ether, 5000e6);
        console.log("Large position residual (raw sum):", largeResidual);

        assertGt(largeResidual, smallResidual, "Larger position -> larger residual");
    }

    /// @dev Mints a position around the current tick at the given deposit
    ///      sizes, displaces the price, rebalances to a wider range, and
    ///      returns the raw token-sum residual stranded in the depositor's
    ///      mock-balance.
    function _measureResidual(uint256 amount0, uint256 amount1) internal returns (uint256) {
        int24 currentTick = pool.tick();
        int24 tickLower = TickHelpers.nearest(currentTick - 500, 100);
        int24 tickUpper = TickHelpers.nearest(currentTick + 500, 100);

        Position memory pos = _createPosition(tickLower, tickUpper, amount0, amount1);
        pool.movePriceToTick(currentTick + 200);

        uint256 bal0Before = token0Balance;
        uint256 bal1Before = token1Balance;

        int24 newLower = TickHelpers.nearest(currentTick + 200 - 1000, 100);
        int24 newUpper = TickHelpers.nearest(currentTick + 200 + 1000, 100);

        (uint256 w0, uint256 w1) = _withdrawPosition(pos);
        _createPosition(newLower, newUpper, w0, w1);

        return (token0Balance - bal0Before) + (token1Balance - bal1Before);
    }
}
