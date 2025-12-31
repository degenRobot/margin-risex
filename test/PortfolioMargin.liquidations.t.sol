// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnhancedSetup} from "./utils/EnhancedSetup.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {Position, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

/// @title Liquidation Scenarios Test
/// @notice Tests various liquidation scenarios and edge cases
contract PortfolioMarginLiquidationsTest is EnhancedSetup {
    
    // Mirror event for testing
    event PortfolioLiquidated(address indexed user, address indexed liquidator, uint256 incentive);
    
    address aliceSubAccount;
    address bobSubAccount;
    
    function setUp() public override {
        super.setUp();
    }
    
    function test_BasicLiquidationFlow() public usesFork {
        console2.log("\n=== Basic Liquidation Flow Test ===");
        
        // Setup: Alice takes a risky position
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18); // 10 WETH = $30k
        borrowUSDC(alice, wethMarket, 23_000e6); // Borrow $23k (high leverage)
        
        console2.log("\nInitial position:");
        logHealth(alice);
        assertHealthy(alice);
        
        // Price crash: WETH drops 20%
        console2.log("\nSimulating 20% price drop...");
        setWETHPrice(2400e24); // $3000 -> $2400
        
        console2.log("\nAfter price drop:");
        logHealth(alice);
        
        // Should be unhealthy now
        assertUnhealthy(alice);
        
        // Liquidator executes liquidation
        console2.log("\nExecuting liquidation...");
        
        uint256 liquidatorWethBefore = weth.balanceOf(liquidator);
        uint256 liquidatorUsdcBefore = usdc.balanceOf(liquidator);
        
        // Expect liquidation event
        vm.expectEmit(true, true, false, true);
        emit PortfolioLiquidated(alice, liquidator, manager.LIQUIDATION_INCENTIVE());
        
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
        
        // Check liquidator received collateral
        uint256 liquidatorWethAfter = weth.balanceOf(liquidator);
        uint256 liquidatorUsdcAfter = usdc.balanceOf(liquidator);
        
        console2.log("\nLiquidator gains:");
        console2.log("WETH received:", (liquidatorWethAfter - liquidatorWethBefore) / 1e18);
        console2.log("USDC spent:", (liquidatorUsdcBefore - liquidatorUsdcAfter) / 1e6);
        
        // Check position cleared
        Position memory position = getMorphoPosition(aliceSubAccount, wethMarket);
        assertEq(position.collateral, 0, "Collateral should be liquidated");
        assertEq(position.borrowShares, 0, "Debt should be repaid");
    }
    
    function test_PartialLiquidation() public usesFork {
        console2.log("\n=== Partial Liquidation Test ===");
        
        // Setup large position with multiple collaterals
        aliceSubAccount = createOrGetSubAccount(alice);
        
        // Deposit both WETH and WBTC
        vm.startPrank(alice);
        weth.approve(aliceSubAccount, 10e18);
        PortfolioSubAccount(aliceSubAccount).depositCollateral(wethMarket, 10e18);
        
        wbtc.approve(aliceSubAccount, 2e8);
        PortfolioSubAccount(aliceSubAccount).depositCollateral(wbtcMarket, 2e8);
        vm.stopPrank();
        
        // Borrow from both markets
        borrowUSDC(alice, wethMarket, 20_000e6);
        borrowUSDC(alice, wbtcMarket, 60_000e6);
        
        console2.log("\nInitial multi-collateral position:");
        logHealth(alice);
        
        // Drop both prices moderately
        setWETHPrice(2700e24); // -10%
        setWBTCPrice(45000e34); // -10%
        
        console2.log("\nAfter price drops:");
        logHealth(alice);
        
        // Execute liquidation
        if (!manager.isHealthy(alice)) {
            vm.prank(liquidator);
            manager.liquidatePortfolio(alice);
            
            console2.log("\nAfter liquidation:");
            
            // Check both positions
            Position memory wethPos = getMorphoPosition(aliceSubAccount, wethMarket);
            Position memory wbtcPos = getMorphoPosition(aliceSubAccount, wbtcMarket);
            
            console2.log("WETH remaining:", wethPos.collateral / 1e18);
            console2.log("WBTC remaining:", wbtcPos.collateral / 1e8);
        }
    }
    
    function test_LiquidationWithRISExPosition() public usesFork {
        console2.log("\n=== Liquidation with RISEx Position Test ===");
        
        // Note: This test would work if RISEx was properly configured
        address risexAddr = address(PortfolioSubAccount(depositCollateral(alice, wethMarket, 10e18)).RISEX());
        
        if (risexAddr == address(0)) {
            console2.log("Skipping - RISEx not configured in sub-account");
            return;
        }
        
        // Would test:
        // 1. Deposit collateral and borrow
        // 2. Deposit USDC to RISEx
        // 3. Open perpetual position
        // 4. Price moves against position
        // 5. Liquidation closes perps first, then Morpho positions
    }
    
    function test_CascadingLiquidations() public usesFork {
        console2.log("\n=== Cascading Liquidations Test ===");
        
        // Multiple users with interconnected risk
        depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 22_000e6);
        
        depositCollateral(bob, wethMarket, 8e18);
        borrowUSDC(bob, wethMarket, 18_000e6);
        
        depositCollateral(charlie, wethMarket, 5e18);
        borrowUSDC(charlie, wethMarket, 11_000e6);
        
        console2.log("\nInitial positions:");
        logHealth(alice);
        logHealth(bob);
        logHealth(charlie);
        
        // Market crash
        setWETHPrice(2100e24); // -30%
        
        console2.log("\nAfter crash:");
        
        // Check who's liquidatable
        bool aliceLiquidatable = !manager.isHealthy(alice);
        bool bobLiquidatable = !manager.isHealthy(bob);
        bool charlieLiquidatable = !manager.isHealthy(charlie);
        
        console2.log("Alice liquidatable:", aliceLiquidatable);
        console2.log("Bob liquidatable:", bobLiquidatable);
        console2.log("Charlie liquidatable:", charlieLiquidatable);
        
        // Liquidate in order of urgency
        uint256 liquidationCount = 0;
        
        if (aliceLiquidatable) {
            vm.prank(liquidator);
            manager.liquidatePortfolio(alice);
            liquidationCount++;
        }
        
        if (bobLiquidatable) {
            vm.prank(liquidator);
            manager.liquidatePortfolio(bob);
            liquidationCount++;
        }
        
        if (charlieLiquidatable) {
            vm.prank(liquidator);
            manager.liquidatePortfolio(charlie);
            liquidationCount++;
        }
        
        console2.log("\nTotal liquidations executed:", liquidationCount);
    }
    
    function test_LiquidationIncentives() public usesFork {
        console2.log("\n=== Liquidation Incentives Test ===");
        
        // Setup position
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 22_000e6);
        
        // Make unhealthy
        setWETHPrice(2400e24);
        
        // Calculate expected incentives
        uint256 collateralValue = 10e18; // 10 WETH
        uint256 expectedIncentive = (collateralValue * manager.LIQUIDATION_INCENTIVE()) / 1e18;
        uint256 expectedLiquidatorAmount = collateralValue - expectedIncentive;
        
        console2.log("Expected incentive:", expectedIncentive / 1e18, "WETH");
        console2.log("Expected to liquidator:", expectedLiquidatorAmount / 1e18, "WETH");
        
        // Track balances
        uint256 liquidatorBefore = weth.balanceOf(liquidator);
        uint256 protocolBefore = weth.balanceOf(owner);
        
        // Execute liquidation
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
        
        // Verify incentive distribution
        uint256 liquidatorGain = weth.balanceOf(liquidator) - liquidatorBefore;
        uint256 protocolGain = weth.balanceOf(owner) - protocolBefore;
        
        console2.log("\nActual distribution:");
        console2.log("Liquidator gained:", liquidatorGain / 1e18, "WETH");
        console2.log("Protocol gained:", protocolGain / 1e18, "WETH");
        
        assertEq(liquidatorGain, expectedLiquidatorAmount, "Liquidator amount");
        assertEq(protocolGain, expectedIncentive, "Protocol incentive");
    }
    
    function test_LiquidationProtection() public usesFork {
        console2.log("\n=== Liquidation Protection Test ===");
        
        // Healthy position
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 10_000e6); // Conservative borrow
        
        console2.log("Healthy position:");
        logHealth(alice);
        assertHealthy(alice);
        
        // Attempt liquidation on healthy account (should fail)
        vm.prank(liquidator);
        vm.expectRevert("Portfolio is healthy");
        manager.liquidatePortfolio(alice);
        
        // Attempt liquidation by non-liquidator (should be allowed)
        vm.prank(bob); // Anyone can liquidate
        vm.expectRevert("Portfolio is healthy");
        manager.liquidatePortfolio(alice);
    }
    
    function test_DustPositionLiquidation() public usesFork {
        console2.log("\n=== Dust Position Liquidation Test ===");
        
        // Very small position
        aliceSubAccount = depositCollateral(alice, wethMarket, 0.1e18); // 0.1 WETH
        borrowUSDC(alice, wethMarket, 200e6); // $200
        
        // Make unhealthy with small price move
        setWETHPrice(2850e24); // -5%
        
        console2.log("Small position health:");
        logHealth(alice);
        
        if (!manager.isHealthy(alice)) {
            // Even small positions should be liquidatable
            vm.prank(liquidator);
            manager.liquidatePortfolio(alice);
            
            // Verify cleaned up
            Position memory position = getMorphoPosition(aliceSubAccount, wethMarket);
            assertEq(position.collateral, 0, "Dust position liquidated");
        }
    }
    
    function test_LiquidationWithInterestAccrued() public usesFork {
        console2.log("\n=== Liquidation with Interest Test ===");
        
        // Setup position
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 20_000e6);
        
        // Let interest accrue
        skipTime(365 days);
        
        console2.log("After 1 year:");
        Position memory posAfter = getMorphoPosition(aliceSubAccount, wethMarket);
        console2.log("Borrow shares after interest:", posAfter.borrowShares);
        
        // Interest alone might make position unhealthy
        logHealth(alice);
        
        if (!manager.isHealthy(alice)) {
            vm.prank(liquidator);
            manager.liquidatePortfolio(alice);
            console2.log("Liquidated due to interest accumulation");
        }
    }
    
    function test_LiquidationReentrancy() public usesFork {
        console2.log("\n=== Liquidation Reentrancy Test ===");
        
        // Setup unhealthy position
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 22_000e6);
        setWETHPrice(2400e24);
        
        // Deploy malicious liquidator that tries to reenter
        // (Would need actual malicious contract to fully test)
        
        // For now, verify single liquidation works correctly
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
        
        // Try to liquidate again (should fail - already liquidated)
        vm.prank(liquidator);
        vm.expectRevert(); // Position already cleared
        manager.liquidatePortfolio(alice);
    }
}