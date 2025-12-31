// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnhancedSetup} from "./utils/EnhancedSetup.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {MarketParams, Id, Position} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

/// @title Market Management Test
/// @notice Tests for managing Morpho markets in the portfolio system
contract PortfolioMarginMarketsTest is EnhancedSetup {
    
    function setUp() public override {
        super.setUp();
    }
    
    function test_MarketConfiguration() public usesFork {
        console2.log("\n=== Market Configuration Test ===");
        
        // Check WETH market configuration
        // Public mappings of structs return individual values
        (bool wethSupported, uint256 wethCollateralFactor, MarketParams memory wethParams) = 
            manager.marketConfigs(Id.wrap(WETH_MARKET_ID));
            
        console2.log("WETH Market:");
        console2.log("  Supported:", wethSupported);
        console2.log("  Collateral Factor:", wethCollateralFactor * 100 / 1e18, "%");
        console2.log("  LLTV:", wethParams.lltv * 100 / 1e18, "%");
        
        assertTrue(wethSupported, "WETH market should be supported");
        assertEq(wethCollateralFactor, 0.85e18, "85% collateral factor");
        assertEq(wethParams.lltv, 0.77e18, "77% LLTV");
        
        // Check WBTC market
        (bool wbtcSupported, uint256 wbtcCollateralFactor, MarketParams memory wbtcParams) = 
            manager.marketConfigs(Id.wrap(WBTC_MARKET_ID));
            
        console2.log("\nWBTC Market:");
        console2.log("  Supported:", wbtcSupported);
        console2.log("  Collateral Factor:", wbtcCollateralFactor * 100 / 1e18, "%");
        console2.log("  LLTV:", wbtcParams.lltv * 100 / 1e18, "%");
        
        assertTrue(wbtcSupported, "WBTC market should be supported");
    }
    
    function test_UnsupportedMarket() public usesFork {
        console2.log("\n=== Unsupported Market Test ===");
        
        // Create a new market that's not supported
        MarketParams memory unsupportedMarket = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(makeAddr("RANDOM_TOKEN")),
            oracle: address(wethOracle), // Reuse oracle for simplicity
            irm: IRM,
            lltv: 0.5e18
        });
        
        // Try to use unsupported market
        address subAccount = createOrGetSubAccount(alice);
        
        vm.prank(alice);
        vm.expectRevert(); // Should revert as market not added to manager
        PortfolioSubAccount(subAccount).depositCollateral(unsupportedMarket, 1e18);
    }
    
    function test_MarketRiskParameters() public usesFork {
        console2.log("\n=== Market Risk Parameters Test ===");
        
        // Test that collateral factor affects borrowing power
        address subAccount = depositCollateral(alice, wethMarket, 10e18); // $30k worth
        
        // With 85% collateral factor: $30k * 0.85 = $25.5k borrowing power
        // With 77% LLTV, Morpho allows up to: $30k * 0.77 = $23.1k
        // Portfolio margin is more conservative (85% factor)
        
        // Should be able to borrow up to ~$25k
        borrowUSDC(alice, wethMarket, 25_000e6);
        
        console2.log("Borrowed at limit:");
        logHealth(alice);
        
        // Trying to borrow more should fail
        vm.prank(alice);
        vm.expectRevert();
        PortfolioSubAccount(subAccount).borrowUSDC(wethMarket, 1_000e6);
    }
    
    function test_MultipleMarketsRiskAggregation() public usesFork {
        console2.log("\n=== Multiple Markets Risk Aggregation Test ===");
        
        address subAccount = createOrGetSubAccount(alice);
        
        // Deposit in both markets
        vm.startPrank(alice);
        weth.approve(subAccount, 5e18);
        PortfolioSubAccount(subAccount).depositCollateral(wethMarket, 5e18); // $15k
        
        wbtc.approve(subAccount, 1e8);
        PortfolioSubAccount(subAccount).depositCollateral(wbtcMarket, 1e8); // $50k
        vm.stopPrank();
        
        // Total collateral value: $65k
        // With 85% factor: $55.25k borrowing power
        
        console2.log("\nAfter multi-market deposits:");
        (uint256 collateralValue, , , , ) = getHealth(alice);
        console2.log("Total collateral value: $", collateralValue / 1e6);
        
        // Should aggregate correctly
        assertEq(collateralValue, 55_250e6, "Total adjusted collateral value");
        
        // Borrow from different markets
        borrowUSDC(alice, wethMarket, 15_000e6);
        borrowUSDC(alice, wbtcMarket, 35_000e6);
        
        console2.log("\nAfter borrowing from both markets:");
        logHealth(alice);
        
        // Total debt: $50k, should still be healthy
        assertHealthy(alice);
    }
    
    function test_MarketOracleIntegration() public usesFork {
        console2.log("\n=== Market Oracle Integration Test ===");
        
        // Check oracle prices are used correctly
        uint256 wethOraclePrice = wethOracle.price();
        uint256 wbtcOraclePrice = wbtcOracle.price();
        
        console2.log("Oracle prices:");
        console2.log("WETH:", wethOraclePrice / 1e24, "USD (24 decimals)");
        console2.log("WBTC:", wbtcOraclePrice / 1e34, "USD (34 decimals)");
        
        // Deposit and check valuation
        address subAccount = depositCollateral(alice, wethMarket, 1e18); // 1 WETH
        
        (uint256 collateralValue, , , , ) = getHealth(alice);
        
        // Should be 1 WETH * $3000 * 85% = $2550
        uint256 expectedValue = (1e18 * 3000 * 85) / 100;
        assertEq(collateralValue, expectedValue * 1e6, "Collateral valued correctly");
    }
    
    function test_MarketInterestAccrual() public usesFork {
        console2.log("\n=== Market Interest Accrual Test ===");
        
        // Setup position
        depositCollateral(alice, wethMarket, 10e18);
        borrowUSDC(alice, wethMarket, 10_000e6);
        
        Position memory posBefore = getMorphoPosition(
            manager.userSubAccounts(alice),
            wethMarket
        );
        console2.log("Initial borrow shares:", posBefore.borrowShares);
        
        // Skip time
        skipTime(365 days);
        
        Position memory posAfter = getMorphoPosition(
            manager.userSubAccounts(alice),
            wethMarket
        );
        console2.log("Borrow shares after 1 year:", posAfter.borrowShares);
        
        // Shares should remain same, but the value they represent increases
        assertEq(posAfter.borrowShares, posBefore.borrowShares, "Shares remain constant");
    }
    
    function test_MarketLiquidityConstraints() public usesFork {
        console2.log("\n=== Market Liquidity Constraints Test ===");
        
        // Check market liquidity
        uint256 morphoUSDCBalance = usdc.balanceOf(address(morpho));
        console2.log("Morpho USDC balance:", morphoUSDCBalance / 1e6, "USDC");
        
        // Deposit collateral
        depositCollateral(alice, wethMarket, 100e18); // Large deposit
        
        // Try to borrow more than available liquidity
        if (morphoUSDCBalance < 200_000e6) {
            console2.log("Limited liquidity scenario");
            
            // Should be limited by available USDC in Morpho
            vm.prank(alice);
            vm.expectRevert(); // Insufficient liquidity
            PortfolioSubAccount(manager.userSubAccounts(alice))
                .borrowUSDC(wethMarket, morphoUSDCBalance + 1e6);
        }
    }
    
    function test_MarketPauseScenario() public usesFork {
        console2.log("\n=== Market Pause Scenario Test ===");
        
        // Note: Morpho doesn't have pause functionality in base protocol
        // This test would check emergency scenarios if implemented
        
        // For now, verify normal operations work
        depositCollateral(alice, wethMarket, 5e18);
        borrowUSDC(alice, wethMarket, 10_000e6);
        
        console2.log("Normal operations confirmed");
        assertHealthy(alice);
    }
    
    function test_CrossMarketLiquidation() public usesFork {
        console2.log("\n=== Cross-Market Liquidation Test ===");
        
        // Setup positions in both markets
        address subAccount = createOrGetSubAccount(alice);
        
        vm.startPrank(alice);
        weth.approve(subAccount, 5e18);
        PortfolioSubAccount(subAccount).depositCollateral(wethMarket, 5e18);
        
        wbtc.approve(subAccount, 1e8);
        PortfolioSubAccount(subAccount).depositCollateral(wbtcMarket, 1e8);
        vm.stopPrank();
        
        // Borrow from both
        borrowUSDC(alice, wethMarket, 12_000e6);
        borrowUSDC(alice, wbtcMarket, 38_000e6);
        
        console2.log("\nInitial cross-market position:");
        logHealth(alice);
        
        // Drop one collateral price significantly
        setWBTCPrice(35000e34); // -30%
        
        console2.log("\nAfter WBTC crash:");
        logHealth(alice);
        
        if (!manager.isHealthy(alice)) {
            // Liquidation should handle both markets
            vm.prank(liquidator);
            manager.liquidatePortfolio(alice);
            
            // Check both markets cleared
            Position memory wethPos = getMorphoPosition(subAccount, wethMarket);
            Position memory wbtcPos = getMorphoPosition(subAccount, wbtcMarket);
            
            console2.log("\nAfter liquidation:");
            console2.log("WETH position cleared:", wethPos.collateral == 0);
            console2.log("WBTC position cleared:", wbtcPos.collateral == 0);
        }
    }
}