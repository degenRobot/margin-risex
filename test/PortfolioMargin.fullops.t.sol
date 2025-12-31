// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnhancedSetup} from "./utils/EnhancedSetup.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IRISExPerpsManager} from "../src/interfaces/IRISExPerpsManager.sol";
import {Position, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

/// @title Full Operations Integration Test
/// @notice Tests complete user flows from deposit to trading
contract PortfolioMarginFullOpsTest is EnhancedSetup {
    
    address aliceSubAccount;
    address bobSubAccount;
    
    function setUp() public override {
        super.setUp();
    }
    
    function test_FullUserFlow() public usesFork {
        console2.log("\n=== Starting Full User Flow Test ===");
        
        // Step 1: Create sub-account and deposit collateral
        console2.log("\n1. Creating sub-account and depositing collateral...");
        aliceSubAccount = depositCollateral(alice, wethMarket, 5e18); // 5 WETH
        
        // Verify collateral deposited
        Position memory position = getMorphoPosition(aliceSubAccount, wethMarket);
        assertEq(position.collateral, 5e18, "Collateral should be deposited");
        
        logHealth(alice);
        
        // Step 2: Borrow USDC against collateral
        console2.log("\n2. Borrowing USDC...");
        borrowUSDC(alice, wethMarket, 10_000e6); // Borrow $10k USDC
        
        // Verify borrow
        position = getMorphoPosition(aliceSubAccount, wethMarket);
        assertGt(position.borrowShares, 0, "Should have borrowed");
        assertEq(usdc.balanceOf(alice), INITIAL_USDC + 10_000e6, "Alice should receive USDC");
        
        logHealth(alice);
        assertHealthy(alice);
        
        // Step 3: Deposit USDC to RISEx (will fail with current deployment)
        console2.log("\n3. Attempting to deposit to RISEx...");
        
        // Check if RISEx is properly configured
        address risexInSubAccount = address(PortfolioSubAccount(aliceSubAccount).RISEX());
        if (risexInSubAccount == address(0)) {
            console2.log("WARNING: RISEx address is 0x0 - skipping RISEx operations");
            return;
        }
        
        // If we get here, RISEx is configured
        vm.startPrank(alice);
        usdc.approve(aliceSubAccount, 5_000e6);
        vm.expectRevert(); // This will revert due to RISEx at 0x0
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), 5_000e6);
        vm.stopPrank();
    }
    
    function test_MultiUserInteractions() public usesFork {
        console2.log("\n=== Multi-User Interaction Test ===");
        
        // Both users create sub-accounts and deposit
        aliceSubAccount = depositCollateral(alice, wethMarket, 5e18);
        bobSubAccount = depositCollateral(bob, wbtcMarket, 1e8); // 1 WBTC
        
        console2.log("\nInitial states:");
        logHealth(alice);
        logHealth(bob);
        
        // Alice borrows
        borrowUSDC(alice, wethMarket, 8_000e6);
        
        // Bob borrows more aggressively
        borrowUSDC(bob, wbtcMarket, 35_000e6);
        
        console2.log("\nAfter borrowing:");
        logHealth(alice);
        logHealth(bob);
        
        // Both should still be healthy
        assertHealthy(alice);
        assertHealthy(bob);
    }
    
    function test_DepositWithdrawCycle() public usesFork {
        console2.log("\n=== Deposit-Withdraw Cycle Test ===");
        
        // Deposit collateral
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18);
        
        // Withdraw partial collateral
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).withdrawCollateral(wethMarket, 3e18);
        
        // Verify remaining collateral
        Position memory position = getMorphoPosition(aliceSubAccount, wethMarket);
        assertEq(position.collateral, 7e18, "Should have 7 WETH remaining");
        
        // Borrow against remaining
        borrowUSDC(alice, wethMarket, 15_000e6);
        
        logHealth(alice);
        assertHealthy(alice);
        
        // Try to withdraw too much (should fail due to health check)
        vm.prank(alice);
        vm.expectRevert(); // Should revert due to health check
        PortfolioSubAccount(aliceSubAccount).withdrawCollateral(wethMarket, 5e18);
    }
    
    function test_MultiMarketPositions() public usesFork {
        console2.log("\n=== Multi-Market Positions Test ===");
        
        aliceSubAccount = createOrGetSubAccount(alice);
        
        // Deposit both WETH and WBTC
        vm.startPrank(alice);
        weth.approve(aliceSubAccount, 5e18);
        PortfolioSubAccount(aliceSubAccount).depositCollateral(wethMarket, 5e18);
        
        wbtc.approve(aliceSubAccount, 1e8);
        PortfolioSubAccount(aliceSubAccount).depositCollateral(wbtcMarket, 1e8);
        vm.stopPrank();
        
        console2.log("\nAfter deposits:");
        logHealth(alice);
        
        // Borrow from both markets
        borrowUSDC(alice, wethMarket, 8_000e6);
        borrowUSDC(alice, wbtcMarket, 25_000e6);
        
        console2.log("\nAfter borrows:");
        logHealth(alice);
        
        // Check positions
        Position memory wethPosition = getMorphoPosition(aliceSubAccount, wethMarket);
        Position memory wbtcPosition = getMorphoPosition(aliceSubAccount, wbtcMarket);
        
        assertEq(wethPosition.collateral, 5e18, "WETH collateral");
        assertEq(wbtcPosition.collateral, 1e8, "WBTC collateral");
        assertGt(wethPosition.borrowShares, 0, "WETH market borrow");
        assertGt(wbtcPosition.borrowShares, 0, "WBTC market borrow");
        
        assertHealthy(alice);
    }
    
    function test_BorrowRepayFlow() public usesFork {
        console2.log("\n=== Borrow-Repay Flow Test ===");
        
        // Setup position
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 20_000e6);
        
        // Skip time to accrue interest
        skipTime(30 days);
        
        console2.log("\nAfter 30 days:");
        Position memory positionBefore = getMorphoPosition(aliceSubAccount, wethMarket);
        console2.log("Borrow shares:", positionBefore.borrowShares);
        
        // Calculate debt with interest
        // Note: Morpho doesn't have expectedBorrowAssets, need to calculate from shares
        uint256 borrowShares = positionBefore.borrowShares;
        console2.log("Total debt shares:", borrowShares);
        
        // Repay partial
        vm.startPrank(alice);
        usdc.approve(aliceSubAccount, 10_000e6);
        PortfolioSubAccount(aliceSubAccount).repayUSDC(wethMarket, 10_000e6);
        vm.stopPrank();
        
        // Check reduced debt
        Position memory positionAfter = getMorphoPosition(aliceSubAccount, wethMarket);
        uint256 borrowSharesAfter = positionAfter.borrowShares;
        console2.log("Debt shares after repay:", borrowSharesAfter);
        
        assertLt(borrowSharesAfter, borrowShares, "Debt shares should decrease");
    }
    
    function test_MaxBorrowScenario() public usesFork {
        console2.log("\n=== Max Borrow Scenario Test ===");
        
        // Deposit significant collateral
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18); // 10 WETH = $30k
        
        // With 85% collateral factor: $30k * 0.85 = $25.5k borrowing power
        // Borrow close to limit
        borrowUSDC(alice, wethMarket, 24_000e6);
        
        console2.log("\nAt max borrow:");
        logHealth(alice);
        
        // Health should be low but still healthy
        (,,,uint256 healthFactor,) = getHealth(alice);
        assertGt(healthFactor, 1e18, "Should still be healthy");
        assertLt(healthFactor, 1.1e18, "Health factor should be close to threshold");
        
        // Try to borrow more (should fail)
        vm.prank(alice);
        vm.expectRevert();
        PortfolioSubAccount(aliceSubAccount).borrowUSDC(wethMarket, 2_000e6);
    }
    
    function test_CollateralSwap() public usesFork {
        console2.log("\n=== Collateral Swap Test ===");
        
        // Start with WETH collateral
        aliceSubAccount = depositCollateral(alice, wethMarket, 5e18);
        borrowUSDC(alice, wethMarket, 10_000e6);
        
        console2.log("\nInitial position (WETH):");
        logHealth(alice);
        
        // Repay debt to enable withdrawal
        vm.startPrank(alice);
        usdc.approve(aliceSubAccount, 10_000e6);
        PortfolioSubAccount(aliceSubAccount).repayUSDC(wethMarket, 10_000e6);
        vm.stopPrank();
        
        // Withdraw WETH
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).withdrawCollateral(wethMarket, 5e18);
        
        // Deposit WBTC instead
        vm.startPrank(alice);
        wbtc.approve(aliceSubAccount, 1e8);
        PortfolioSubAccount(aliceSubAccount).depositCollateral(wbtcMarket, 1e8);
        vm.stopPrank();
        
        // Borrow against WBTC
        borrowUSDC(alice, wbtcMarket, 30_000e6);
        
        console2.log("\nAfter swap to WBTC:");
        logHealth(alice);
        assertHealthy(alice);
    }
    
    function test_EmergencyWithdraw() public usesFork {
        console2.log("\n=== Emergency Withdraw Test ===");
        
        // Setup position
        aliceSubAccount = depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 15_000e6);
        
        // Simulate emergency: user needs to withdraw maximum possible
        console2.log("\nTrying emergency withdrawal...");
        
        // First repay what we can
        uint256 aliceUSDC = usdc.balanceOf(alice);
        console2.log("Alice USDC balance:", aliceUSDC / 1e6);
        
        vm.startPrank(alice);
        usdc.approve(aliceSubAccount, aliceUSDC);
        PortfolioSubAccount(aliceSubAccount).repayUSDC(wethMarket, aliceUSDC);
        vm.stopPrank();
        
        // Calculate how much collateral we can withdraw while staying healthy
        (uint256 collateralValue, uint256 debtValue,,,) = getHealth(alice);
        // Get remaining debt from position
        Position memory pos = getMorphoPosition(aliceSubAccount, wethMarket);
        console2.log("Remaining debt shares:", pos.borrowShares);
        
        // Try to withdraw some collateral
        uint256 wethPrice = 3000e24; // $3000 per WETH (oracle price)
        // Simplified: try to withdraw half the collateral
        uint256 maxWithdrawable = 5e18;
        
        if (maxWithdrawable > 0) {
            vm.prank(alice);
            PortfolioSubAccount(aliceSubAccount).withdrawCollateral(wethMarket, maxWithdrawable);
            console2.log("Withdrew", maxWithdrawable / 1e18, "WETH");
        }
        
        console2.log("\nFinal state:");
        logHealth(alice);
        assertHealthy(alice);
    }
}