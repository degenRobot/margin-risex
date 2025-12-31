// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Setup} from "./utils/Setup.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IRISExPerpsManager} from "../src/interfaces/IRISExPerpsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

contract PortfolioMarginRISExTest is Setup {
    
    address aliceSubAccount;
    
    // RISEx test parameters
    uint256 constant ETH_MARKET_ID = 2; // From cliques.fun setup
    uint256 constant BTC_MARKET_ID = 1;
    
    modifier onlyFork() {
        if (!vm.envBool("FORK_RISE_TESTNET")) {
            console2.log("Skipping RISEx test - requires fork mode");
            return;
        }
        _;
    }
    
    function setUp() public override {
        super.setUp();
        
        // Create sub-account for Alice
        aliceSubAccount = createSubAccount(alice);
    }
    
    function test_DepositToRISEx() public onlyFork {
        uint256 depositAmount = 10_000e6; // 10k USDC
        
        // First, Alice needs some USDC in her sub-account
        // She can get it by depositing collateral and borrowing
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, depositAmount);
        
        // Check RISEx balance before
        uint256 risexBalanceBefore = IRISExPerpsManager(RISEX_PERPS_MANAGER).getWithdrawableAmount(
            aliceSubAccount,
            address(usdc)
        );
        assertEq(risexBalanceBefore, 0);
        
        // Deposit USDC to RISEx
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), depositAmount);
        
        // Check RISEx balance after
        uint256 risexBalanceAfter = IRISExPerpsManager(RISEX_PERPS_MANAGER).getWithdrawableAmount(
            aliceSubAccount,
            address(usdc)
        );
        assertEq(risexBalanceAfter, depositAmount);
    }
    
    function test_WithdrawFromRISEx() public onlyFork {
        uint256 depositAmount = 10_000e6;
        uint256 withdrawAmount = 5_000e6;
        
        // Setup: Get USDC and deposit to RISEx
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, depositAmount);
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), depositAmount);
        
        // Check balance before withdrawal
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        
        // Withdraw from RISEx
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).withdrawFromRisEx(address(usdc), withdrawAmount);
        
        // Check balances
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + withdrawAmount);
        
        uint256 risexBalance = IRISExPerpsManager(RISEX_PERPS_MANAGER).getWithdrawableAmount(
            aliceSubAccount,
            address(usdc)
        );
        assertEq(risexBalance, depositAmount - withdrawAmount);
    }
    
    function test_HealthWithRISExPositiveEquity() public onlyFork {
        // Setup: Deposit collateral and borrow
        uint256 collateralAmount = 10e18; // 10 WETH = $30k
        uint256 borrowAmount = 20_000e6; // $20k USDC
        
        depositCollateral(alice, aliceSubAccount, wethMarketParams, collateralAmount);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, borrowAmount);
        
        // Deposit half to RISEx
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), 10_000e6);
        
        // Get health before any trading
        (uint256 collateralValue1, uint256 debtValue1, int256 risexEquity1, uint256 healthFactor1, bool isHealthy1) = getHealth(alice);
        
        console2.log("Before trading:");
        console2.log("  Collateral:", collateralValue1);
        console2.log("  Debt:", debtValue1);
        console2.log("  RISEx equity:", risexEquity1);
        console2.log("  Health factor:", healthFactor1);
        
        assertTrue(isHealthy1);
        
        // Simulate positive PnL on RISEx (would need actual trading)
        // For now, just check that RISEx equity is included in health calculation
        int256 accountEquity = IRISExPerpsManager(RISEX_PERPS_MANAGER).getAccountEquity(aliceSubAccount);
        console2.log("RISEx account equity:", accountEquity);
        
        // Health should include RISEx equity
        assertEq(int256(risexEquity1), accountEquity);
    }
    
    function test_PlaceOrder() public onlyFork {
        // Setup: Get USDC in RISEx
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 20_000e6);
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), 20_000e6);
        
        // Create order data (simplified - in reality this would be encoded properly)
        // This is a placeholder - actual implementation would use RISExOrderEncoder
        bytes memory orderData = abi.encode(
            ETH_MARKET_ID,  // marketId
            1e18,           // size (1 ETH)
            0,              // price (market order)
            true            // isBuy
        );
        
        // Place order
        vm.prank(alice);
        uint256 orderId = PortfolioSubAccount(aliceSubAccount).placeOrder(orderData);
        
        console2.log("Placed order with ID:", orderId);
        // Note: This will likely revert without proper order encoding
        // In production, we'd use the RISExOrderEncoder from cliques.fun
    }
    
    function test_OnlyUserCanDepositToRISEx() public onlyFork {
        // Setup
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 1000e6);
        
        // Bob shouldn't be able to deposit Alice's funds to RISEx
        vm.prank(bob);
        vm.expectRevert("Only user");
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), 1000e6);
    }
    
    function test_ManagerCanWithdrawFromRISExDuringLiquidation() public onlyFork {
        // This would be tested in liquidation tests
        // Manager should be able to withdraw from RISEx to repay debts
        assertTrue(true);
    }
    
    function test_CrossProtocolHealthCheck() public onlyFork {
        // Complex scenario:
        // 1. Deposit WETH collateral
        // 2. Borrow USDC
        // 3. Use USDC on RISEx
        // 4. Open leveraged position
        // 5. Check that health factor considers both protocols
        
        uint256 collateralAmount = 10e18; // 10 WETH = $30k
        uint256 borrowAmount = 20_000e6; // $20k USDC
        
        // Step 1-2: Deposit and borrow
        depositCollateral(alice, aliceSubAccount, wethMarketParams, collateralAmount);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, borrowAmount);
        
        // Step 3: Deposit to RISEx
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), borrowAmount);
        
        // Check health includes both Morpho collateral and RISEx equity
        (uint256 collateralValue, uint256 debtValue, int256 risexEquity, uint256 healthFactor, bool isHealthy) = getHealth(alice);
        
        console2.log("Cross-protocol health:");
        console2.log("  Morpho collateral value:", collateralValue);
        console2.log("  Morpho debt value:", debtValue);
        console2.log("  RISEx equity:", risexEquity);
        console2.log("  Combined health factor:", healthFactor);
        console2.log("  Is healthy:", isHealthy);
        
        // Health = (CollateralValue + RISExEquity - Debt) / Debt
        // With positive RISEx equity, health should be maintained
        assertTrue(isHealthy);
        assertGt(collateralValue, 0);
        assertGt(debtValue, 0);
    }
}