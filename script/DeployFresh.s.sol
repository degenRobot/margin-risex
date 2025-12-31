// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";

/// @title DeployFresh
/// @notice Deploy fresh Portfolio Margin System with correct addresses
contract DeployFresh is Script {
    
    // RISE Testnet addresses
    address constant MORPHO = 0x70374FB7a93fD277E66C525B93f810A7D61d5606;
    address constant RISEX_PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    
    // Tokens
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    address constant WBTC = 0x4ea782275171Be21e3Bf50b2Cdfa84B833349AF1;
    
    // Oracles
    address constant WETH_ORACLE = 0xe07eedf78483293348bdcd8F7495d79496F114c0;
    address constant WBTC_ORACLE = 0xdD81dD2FCdCB5BC489a7ea9f694471e540E3492a;
    
    // IRM
    address constant IRM = 0xBcB3924382eF02C1235521ca63DA3071698Eab90;
    
    // Market IDs
    bytes32 constant WETH_MARKET_ID = 0xde3a900dca2c34338462ed11512f3711290848df5ad86ffe17bae4bfcc63339f;
    bytes32 constant WBTC_MARKET_ID = 0xcc27c517e5d8c04d6139bc94f4a64185d4fd73b33607a27c399864d7641a74bd;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Deploying Fresh Portfolio Margin System ===");
        console2.log("Deployer:", deployer);
        console2.log("Morpho:", MORPHO);
        console2.log("RISEx:", RISEX_PERPS_MANAGER);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy PortfolioMarginManager (which deploys sub-account implementation)
        console2.log("1. Deploying PortfolioMarginManager...");
        PortfolioMarginManager manager = new PortfolioMarginManager(
            MORPHO,
            RISEX_PERPS_MANAGER
        );
        console2.log("   PortfolioMarginManager deployed at:", address(manager));
        console2.log("   Sub-account implementation deployed internally");
        
        // Step 2: Add market configurations
        console2.log("\n2. Adding market configurations...");
        
        // WETH Market
        MarketParams memory wethMarket = MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: WETH_ORACLE,
            irm: IRM,
            lltv: 0.77e18 // 77% LLTV
        });
        
        manager.addMarket(wethMarket, 0.85e18); // 85% collateral factor
        console2.log("   Added WETH/USDC market (CF: 85%)");
        
        // WBTC Market (optional)
        MarketParams memory wbtcMarket = MarketParams({
            loanToken: USDC,
            collateralToken: WBTC,
            oracle: WBTC_ORACLE,
            irm: IRM,
            lltv: 0.77e18 // 77% LLTV
        });
        
        manager.addMarket(wbtcMarket, 0.85e18); // 85% collateral factor
        console2.log("   Added WBTC/USDC market (CF: 85%)");
        
        vm.stopBroadcast();
        
        // Display summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("PortfolioMarginManager:", address(manager));
        console2.log("Sub-account impl:", manager.SUB_ACCOUNT_IMPL());
        console2.log("\nMarkets configured:");
        console2.log("- WETH/USDC (CF: 85%)");
        console2.log("- WBTC/USDC (CF: 85%)");
        
        // Predict sub-account address for deployer
        address predictedSubAccount = manager.predictSubAccountAddress(deployer);
        console2.log("\nPredicted sub-account for deployer:", predictedSubAccount);
        
        console2.log("\n[SUCCESS] Deployment complete!");
        
        // Log deployment addresses for record keeping
        console2.log("\nDeployment addresses for records:");
        console2.log("PORTFOLIO_MARGIN_MANAGER=", address(manager));
        console2.log("SUB_ACCOUNT_IMPL=", manager.SUB_ACCOUNT_IMPL());
    }
}