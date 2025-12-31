// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Setup} from "./utils/Setup.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position, Id, Market} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

/// @notice Test Morpho-specific functionality without RISEx
contract PortfolioMarginMorphoTest is Setup {
    
    address aliceSubAccount;
    
    modifier onlyFork() {
        if (!vm.envBool("FORK_RISE_TESTNET")) {
            console2.log("Skipping Morpho test - requires fork mode");
            return;
        }
        _;
    }
    
    function setUp() public override {
        super.setUp();
        
        // For these tests, we'll create sub-accounts directly
        // since the deployed ones have RISEx at address(0)
    }
    
    function test_MorphoMarketsExist() public onlyFork {
        // Check WETH market exists
        Market memory wethMarket = morpho.market(Id.wrap(WETH_MARKET_ID));
        assertGt(wethMarket.lastUpdate, 0, "WETH market should exist");
        
        // Check WBTC market exists
        Market memory wbtcMarket = morpho.market(Id.wrap(WBTC_MARKET_ID));
        assertGt(wbtcMarket.lastUpdate, 0, "WBTC market should exist");
    }
    
    function test_DirectMorphoDeposit() public onlyFork {
        // Test interacting with Morpho directly (not through sub-accounts)
        uint256 depositAmount = 10e18; // 10 WETH
        
        vm.startPrank(alice);
        
        // Approve Morpho
        weth.approve(address(morpho), depositAmount);
        
        // Supply collateral directly
        morpho.supplyCollateral(wethMarketParams, depositAmount, alice, "");
        
        vm.stopPrank();
        
        // Check position
        Position memory position = morpho.position(Id.wrap(WETH_MARKET_ID), alice);
        assertEq(position.collateral, depositAmount);
    }
    
    function test_DirectMorphoBorrow() public onlyFork {
        // First deposit collateral
        uint256 collateralAmount = 10e18; // 10 WETH
        uint256 borrowAmount = 10_000e6; // 10k USDC
        
        vm.startPrank(alice);
        
        // Deposit
        weth.approve(address(morpho), collateralAmount);
        morpho.supplyCollateral(wethMarketParams, collateralAmount, alice, "");
        
        // Borrow
        uint256 balanceBefore = usdc.balanceOf(alice);
        morpho.borrow(wethMarketParams, borrowAmount, 0, alice, alice);
        
        vm.stopPrank();
        
        // Check received USDC
        assertEq(usdc.balanceOf(alice), balanceBefore + borrowAmount);
        
        // Check position
        Position memory position = morpho.position(Id.wrap(WETH_MARKET_ID), alice);
        assertGt(position.borrowShares, 0);
    }
    
    function test_ManagerConfiguration() public onlyFork {
        // Test the manager's market configuration
        (bool isSupported, uint256 collateralFactor,) = manager.marketConfigs(Id.wrap(WETH_MARKET_ID));
        
        assertTrue(isSupported, "WETH market should be supported");
        assertEq(collateralFactor, 0.85e18, "Collateral factor should be 85%");
    }
    
    function test_OraclePrices() public onlyFork {
        // Check oracle prices
        uint256 wethPrice = wethOracle.price();
        console2.log("WETH price:", wethPrice);
        assertEq(wethPrice, 3000 * 10**24, "WETH should be $3000");
        
        uint256 wbtcPrice = wbtcOracle.price();
        console2.log("WBTC price:", wbtcPrice);
        assertEq(wbtcPrice, 50000 * 10**34, "WBTC should be $50000");
    }
    
    function test_IRMRate() public onlyFork {
        // Check IRM rate
        Market memory market = morpho.market(Id.wrap(WETH_MARKET_ID));
        uint256 rate = irm.borrowRate(wethMarketParams, market);
        
        // Should be ~5% APR converted to per-second rate
        uint256 secondsPerYear = 365 days;
        uint256 expectedRate = (0.05e18) / secondsPerYear;
        assertEq(rate, expectedRate, "Rate should be 5% APR");
    }
    
    function test_AccrueInterest() public onlyFork {
        // Setup: deposit and borrow
        vm.startPrank(alice);
        weth.approve(address(morpho), 10e18);
        morpho.supplyCollateral(wethMarketParams, 10e18, alice, "");
        morpho.borrow(wethMarketParams, 10_000e6, 0, alice, alice);
        vm.stopPrank();
        
        // Get initial market state
        Market memory marketBefore = morpho.market(Id.wrap(WETH_MARKET_ID));
        uint256 borrowAssetsBefore = marketBefore.totalBorrowAssets;
        
        // Skip time
        skip(30 days);
        
        // Accrue interest
        morpho.accrueInterest(wethMarketParams);
        
        // Check interest accrued
        Market memory marketAfter = morpho.market(Id.wrap(WETH_MARKET_ID));
        assertGt(marketAfter.totalBorrowAssets, borrowAssetsBefore, "Interest should have accrued");
        
        // Calculate expected interest (roughly)
        uint256 expectedInterest = (borrowAssetsBefore * 5 * 30) / (100 * 365);
        uint256 actualInterest = marketAfter.totalBorrowAssets - borrowAssetsBefore;
        
        // Allow 1% difference due to rounding
        assertApproxEqRel(actualInterest, expectedInterest, 0.01e18);
    }
    
    function test_TokenBalances() public onlyFork {
        // Check initial balances
        assertEq(weth.balanceOf(alice), INITIAL_WETH, "Alice should have initial WETH");
        assertEq(wbtc.balanceOf(alice), INITIAL_WBTC, "Alice should have initial WBTC");
        assertEq(usdc.balanceOf(alice), INITIAL_BALANCE, "Alice should have initial USDC");
    }
}