// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Setup} from "./utils/Setup.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

contract PortfolioMarginBasicTest is Setup {
    
    address aliceSubAccount;
    address bobSubAccount;
    
    function setUp() public override {
        super.setUp();
        
        // Create sub-accounts
        aliceSubAccount = createSubAccount(alice);
        bobSubAccount = createSubAccount(bob);
    }
    
    function test_CreateSubAccount() public {
        // Test creating a new sub-account
        address newUser = makeAddr("newUser");
        address subAccount = manager.createSubAccount(newUser);
        
        // Verify mappings
        assertEq(manager.userSubAccounts(newUser), subAccount);
        assertEq(manager.subAccountUsers(subAccount), newUser);
        
        // Verify sub-account is initialized
        PortfolioSubAccount sa = PortfolioSubAccount(subAccount);
        assertEq(sa.user(), newUser);
        assertTrue(sa.initialized());
    }
    
    function test_CannotCreateDuplicateSubAccount() public {
        address newUser = makeAddr("newUser");
        manager.createSubAccount(newUser);
        
        // Should revert when trying to create again
        vm.expectRevert("Already has sub-account");
        manager.createSubAccount(newUser);
    }
    
    function test_PredictSubAccountAddress() public {
        address newUser = makeAddr("predictableUser");
        
        // Predict address
        address predicted = manager.predictSubAccountAddress(newUser);
        
        // Create sub-account
        address actual = manager.createSubAccount(newUser);
        
        // Should match
        assertEq(predicted, actual);
    }
    
    function test_DepositCollateral() public {
        uint256 depositAmount = 10e18; // 10 WETH
        
        // Check initial balance
        uint256 initialBalance = weth.balanceOf(alice);
        assertEq(initialBalance, INITIAL_WETH);
        
        // Deposit collateral
        depositCollateral(alice, aliceSubAccount, wethMarketParams, depositAmount);
        
        // Check balances
        assertEq(weth.balanceOf(alice), initialBalance - depositAmount);
        
        // Check Morpho position
        Position memory position = morpho.position(Id.wrap(WETH_MARKET_ID), aliceSubAccount);
        assertEq(position.collateral, depositAmount);
    }
    
    function test_BorrowUSDC() public {
        uint256 collateralAmount = 10e18; // 10 WETH
        uint256 borrowAmount = 20_000e6; // 20k USDC
        
        // First deposit collateral
        depositCollateral(alice, aliceSubAccount, wethMarketParams, collateralAmount);
        
        // Check initial USDC balance
        uint256 initialUSDC = usdc.balanceOf(alice);
        
        // Borrow USDC
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, borrowAmount);
        
        // Check USDC received
        assertEq(usdc.balanceOf(alice), initialUSDC + borrowAmount);
        
        // Check position
        Position memory position = morpho.position(Id.wrap(WETH_MARKET_ID), aliceSubAccount);
        assertGt(position.borrowShares, 0);
    }
    
    function test_WithdrawCollateral() public {
        uint256 depositAmount = 10e18; // 10 WETH
        uint256 withdrawAmount = 5e18; // 5 WETH
        
        // Deposit collateral
        depositCollateral(alice, aliceSubAccount, wethMarketParams, depositAmount);
        
        // Check balance before withdrawal
        uint256 balanceBefore = weth.balanceOf(alice);
        
        // Withdraw collateral
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).withdrawCollateral(wethMarketParams, withdrawAmount);
        
        // Check balances
        assertEq(weth.balanceOf(alice), balanceBefore + withdrawAmount);
        
        // Check remaining collateral
        Position memory position = morpho.position(Id.wrap(WETH_MARKET_ID), aliceSubAccount);
        assertEq(position.collateral, depositAmount - withdrawAmount);
    }
    
    function test_RepayUSDC() public {
        uint256 collateralAmount = 10e18; // 10 WETH
        uint256 borrowAmount = 20_000e6; // 20k USDC
        uint256 repayAmount = 10_000e6; // 10k USDC
        
        // Setup: deposit and borrow
        depositCollateral(alice, aliceSubAccount, wethMarketParams, collateralAmount);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, borrowAmount);
        
        // Skip some time to accrue interest
        skipTime(30 days);
        
        // Get shares before repayment
        Position memory positionBefore = morpho.position(Id.wrap(WETH_MARKET_ID), aliceSubAccount);
        uint256 sharesBefore = positionBefore.borrowShares;
        
        // Repay
        vm.startPrank(alice);
        usdc.approve(aliceSubAccount, repayAmount);
        PortfolioSubAccount(aliceSubAccount).repayUSDC(wethMarketParams, repayAmount);
        vm.stopPrank();
        
        // Check shares reduced
        Position memory positionAfter = morpho.position(Id.wrap(WETH_MARKET_ID), aliceSubAccount);
        assertLt(positionAfter.borrowShares, sharesBefore);
    }
    
    function test_HealthFactorCalculation() public {
        // Initial state should be healthy with infinite health factor
        (,,, uint256 healthFactor, bool isHealthy) = getHealth(alice);
        assertEq(healthFactor, type(uint256).max);
        assertTrue(isHealthy);
        
        // Deposit collateral and borrow
        uint256 collateralAmount = 10e18; // 10 WETH = $30k @ $3k/ETH
        uint256 borrowAmount = 20_000e6; // $20k USDC
        
        depositCollateral(alice, aliceSubAccount, wethMarketParams, collateralAmount);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, borrowAmount);
        
        // Check health factor
        (uint256 collateralValue, uint256 debtValue,, uint256 healthFactor2, bool isHealthy2) = getHealth(alice);
        
        console2.log("Collateral value:", collateralValue);
        console2.log("Debt value:", debtValue);
        console2.log("Health factor:", healthFactor2);
        
        // With 85% collateral factor: $30k * 0.85 = $25.5k collateral value
        // Debt: $20k
        // Health = (25.5k - 20k) / 20k = 0.275 = 27.5%
        assertTrue(isHealthy2);
        assertGt(healthFactor2, 0.2e18); // Should be > 20%
        assertLt(healthFactor2, 0.3e18); // Should be < 30%
    }
    
    function test_MultipleMarkets() public {
        // Deposit WETH as collateral
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 5e18); // 5 WETH
        
        // Deposit WBTC as collateral
        depositCollateral(alice, aliceSubAccount, wbtcMarketParams, 2e8); // 2 WBTC
        
        // Borrow from WETH market
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 10_000e6); // 10k USDC
        
        // Borrow from WBTC market
        borrowUSDC(alice, aliceSubAccount, wbtcMarketParams, 30_000e6); // 30k USDC
        
        // Check total portfolio health
        (uint256 collateralValue, uint256 debtValue,, uint256 healthFactor,) = getHealth(alice);
        
        // Total collateral: 5 WETH * $3k + 2 WBTC * $50k = $115k
        // With 85% factor: $97.75k
        // Total debt: $40k
        console2.log("Total collateral value:", collateralValue);
        console2.log("Total debt value:", debtValue);
        console2.log("Health factor:", healthFactor);
        
        assertHealthy(alice);
    }
    
    function test_OnlyUserCanDeposit() public {
        // Bob shouldn't be able to use Alice's sub-account
        vm.prank(bob);
        vm.expectRevert("Only user");
        PortfolioSubAccount(aliceSubAccount).depositCollateral(wethMarketParams, 1e18);
    }
    
    function test_OnlyUserCanBorrow() public {
        // First Alice deposits collateral
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        
        // Bob shouldn't be able to borrow using Alice's sub-account
        vm.prank(bob);
        vm.expectRevert("Only user");
        PortfolioSubAccount(aliceSubAccount).borrowUSDC(wethMarketParams, 1000e6);
    }
    
    function test_OnlyUserCanWithdraw() public {
        // First Alice deposits collateral
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        
        // Bob shouldn't be able to withdraw Alice's collateral
        vm.prank(bob);
        vm.expectRevert("Only user");
        PortfolioSubAccount(aliceSubAccount).withdrawCollateral(wethMarketParams, 1e18);
    }
}