// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Setup} from "./utils/Setup.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {IRISExPerpsManager} from "../src/interfaces/IRISExPerpsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

contract PortfolioMarginLiquidationTest is Setup {
    
    // Mirror event from PortfolioMarginManager for testing
    event PortfolioLiquidated(address indexed user, address indexed liquidator, uint256 incentive);
    
    address aliceSubAccount;
    address bobSubAccount;
    
    function setUp() public override {
        super.setUp();
        
        // Create sub-accounts
        aliceSubAccount = createSubAccount(alice);
        bobSubAccount = createSubAccount(bob);
    }
    
    function test_LiquidationThreshold() public {
        // Setup: Alice deposits collateral and borrows close to limit
        uint256 collateralAmount = 10e18; // 10 WETH = $30k @ $3k
        // With 85% collateral factor and 77% LLTV, max safe borrow is ~$19.5k
        // Let's borrow $19k to be just under threshold
        uint256 borrowAmount = 19_000e6;
        
        depositCollateral(alice, aliceSubAccount, wethMarketParams, collateralAmount);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, borrowAmount);
        
        // Should be healthy
        assertHealthy(alice);
        
        // Drop WETH price by 10%
        uint256 newPrice = 2700 * 10**24; // $2700/ETH
        setOraclePrice(address(wethOracle), newPrice);
        
        // Should now be unhealthy
        assertUnhealthy(alice);
        
        // Check exact health factor
        (,,, uint256 healthFactor,) = getHealth(alice);
        console2.log("Health factor after price drop:", healthFactor);
        assertLt(healthFactor, manager.LIQUIDATION_THRESHOLD());
    }
    
    function test_CannotLiquidateHealthyPortfolio() public {
        // Setup healthy position
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 10_000e6); // Safe amount
        
        assertHealthy(alice);
        
        // Try to liquidate
        vm.prank(liquidator);
        vm.expectRevert("Portfolio is healthy");
        manager.liquidatePortfolio(alice);
    }
    
    function test_BasicLiquidation() public {
        // Setup position that will become unhealthy
        uint256 collateralAmount = 10e18; // 10 WETH
        uint256 borrowAmount = 19_000e6; // $19k USDC
        
        depositCollateral(alice, aliceSubAccount, wethMarketParams, collateralAmount);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, borrowAmount);
        
        // Make unhealthy by dropping price
        setOraclePrice(address(wethOracle), 2400 * 10**24); // $2400/ETH
        assertUnhealthy(alice);
        
        // Record balances before liquidation
        uint256 liquidatorWethBefore = weth.balanceOf(liquidator);
        uint256 ownerWethBefore = weth.balanceOf(owner);
        
        // Liquidate
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
        
        // Check liquidator received collateral minus incentive
        uint256 expectedLiquidatorAmount = (collateralAmount * (1e18 - manager.LIQUIDATION_INCENTIVE())) / 1e18;
        assertEq(weth.balanceOf(liquidator), liquidatorWethBefore + expectedLiquidatorAmount);
        
        // Check protocol owner received incentive
        uint256 expectedIncentive = (collateralAmount * manager.LIQUIDATION_INCENTIVE()) / 1e18;
        assertEq(weth.balanceOf(owner), ownerWethBefore + expectedIncentive);
        
        // Check Alice's position is cleared
        Position memory position = morpho.position(Id.wrap(WETH_MARKET_ID), aliceSubAccount);
        assertEq(position.collateral, 0);
    }
    
    function test_LiquidationWithRISExFunds() public {
        if (!vm.envBool("FORK_RISE_TESTNET")) {
            console2.log("Skipping RISEx liquidation test - requires fork mode");
            return;
        }
        
        // Setup: Position with funds in both Morpho and RISEx
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 20_000e6);
        
        // Put half the borrowed USDC in RISEx
        vm.prank(alice);
        PortfolioSubAccount(aliceSubAccount).depositToRisEx(address(usdc), 10_000e6);
        
        // Make unhealthy
        setOraclePrice(address(wethOracle), 2000 * 10**24); // Drop to $2000/ETH
        assertUnhealthy(alice);
        
        // Liquidate - should withdraw from RISEx first
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
        
        // Check RISEx balance is withdrawn
        uint256 risexBalance = IRISExPerpsManager(RISEX_PERPS_MANAGER).getWithdrawableAmount(
            aliceSubAccount,
            address(usdc)
        );
        assertEq(risexBalance, 0, "RISEx balance should be withdrawn");
    }
    
    function test_PartialDebtRepayment() public {
        // Setup large position
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 20e18); // 20 WETH
        depositCollateral(alice, aliceSubAccount, wbtcMarketParams, 5e8); // 5 WBTC
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 30_000e6);
        borrowUSDC(alice, aliceSubAccount, wbtcMarketParams, 50_000e6);
        
        // Keep 10k USDC in sub-account
        deal(address(usdc), aliceSubAccount, 10_000e6);
        
        // Make unhealthy
        setOraclePrice(address(wethOracle), 1500 * 10**24); // Drop WETH to $1500
        assertUnhealthy(alice);
        
        // Liquidate
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
        
        // Should have used available USDC to repay some debt
        uint256 remainingUSDC = usdc.balanceOf(aliceSubAccount);
        assertEq(remainingUSDC, 0, "All USDC should be used for repayment");
    }
    
    function test_MultiCollateralLiquidation() public {
        // Setup positions in both markets
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        depositCollateral(alice, aliceSubAccount, wbtcMarketParams, 2e8);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 20_000e6);
        borrowUSDC(alice, aliceSubAccount, wbtcMarketParams, 40_000e6);
        
        // Drop both prices to make unhealthy
        setOraclePrice(address(wethOracle), 2000 * 10**24); // $2000/ETH
        setOraclePrice(address(wbtcOracle), 40000 * 10**34); // $40000/BTC
        assertUnhealthy(alice);
        
        // Track liquidator balances
        uint256 liquidatorWethBefore = weth.balanceOf(liquidator);
        uint256 liquidatorWbtcBefore = wbtc.balanceOf(liquidator);
        
        // Liquidate
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
        
        // Check both collaterals were liquidated
        assertGt(weth.balanceOf(liquidator), liquidatorWethBefore);
        assertGt(wbtc.balanceOf(liquidator), liquidatorWbtcBefore);
        
        // Check positions cleared
        Position memory wethPosition = morpho.position(Id.wrap(WETH_MARKET_ID), aliceSubAccount);
        Position memory wbtcPosition = morpho.position(Id.wrap(WBTC_MARKET_ID), aliceSubAccount);
        assertEq(wethPosition.collateral, 0);
        assertEq(wbtcPosition.collateral, 0);
    }
    
    function test_LiquidationEvent() public {
        // Setup unhealthy position
        depositCollateral(alice, aliceSubAccount, wethMarketParams, 10e18);
        borrowUSDC(alice, aliceSubAccount, wethMarketParams, 19_000e6);
        setOraclePrice(address(wethOracle), 2400 * 10**24);
        
        // Expect event
        vm.expectEmit(true, true, false, true);
        emit PortfolioLiquidated(alice, liquidator, manager.LIQUIDATION_INCENTIVE());
        
        // Liquidate
        vm.prank(liquidator);
        manager.liquidatePortfolio(alice);
    }
    
    function test_CannotLiquidateNonExistentAccount() public {
        address randomUser = makeAddr("random");
        
        vm.prank(liquidator);
        vm.expectRevert(); // Will revert when trying to calculate health
        manager.liquidatePortfolio(randomUser);
    }
}