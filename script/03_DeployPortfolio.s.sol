// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseDeployment} from "./BaseDeployment.s.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {MarketParams, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

/// @title DeployPortfolio
/// @notice Deploy portfolio margin system contracts
contract DeployPortfolio is BaseDeployment {
    
    // RISEx PerpsManager address on RISE testnet (placeholder for now)
    address constant RISEX_PERPS_MANAGER = address(0x0000000000000000000000000000000000000000);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Deploying Portfolio Margin System ===");
        console2.log("Deployer:", deployer);
        console2.log("");
        
        // Load existing deployment
        loadDeployment();
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy PortfolioSubAccount implementation
        if (deployment.portfolioSubAccountImpl == address(0)) {
            deployment.portfolioSubAccountImpl = address(new PortfolioSubAccount(
                address(1), // Placeholder manager address
                deployment.morpho,
                RISEX_PERPS_MANAGER
            ));
            console2.log("PortfolioSubAccount implementation deployed at:", deployment.portfolioSubAccountImpl);
        }
        
        // Deploy PortfolioMarginManager
        if (deployment.portfolioMarginManager == address(0)) {
            deployment.portfolioMarginManager = address(new PortfolioMarginManager(
                deployment.morpho,
                RISEX_PERPS_MANAGER
            ));
            console2.log("PortfolioMarginManager deployed at:", deployment.portfolioMarginManager);
        }
        
        PortfolioMarginManager manager = PortfolioMarginManager(deployment.portfolioMarginManager);
        
        // Add WETH market configuration
        MarketParams memory wethMarket = MarketParams({
            loanToken: deployment.usdc,
            collateralToken: deployment.weth,
            oracle: deployment.wethOracle,
            irm: deployment.irm,
            lltv: 0.77e18
        });
        
        console2.log("");
        console2.log("Adding market configurations...");
        
        // Check if market already added
        try manager.marketConfigs(Id.wrap(deployment.wethMarketId)) returns (
            bool isSupported,
            uint256,
            MarketParams memory
        ) {
            if (!isSupported) {
                manager.addMarket(wethMarket, 0.85e18); // 85% collateral factor
                console2.log("Added WETH/USDC market with 85% collateral factor");
            } else {
                console2.log("WETH/USDC market already configured");
            }
        } catch {
            manager.addMarket(wethMarket, 0.85e18); // 85% collateral factor
            console2.log("Added WETH/USDC market with 85% collateral factor");
        }
        
        // Add WBTC market configuration
        MarketParams memory wbtcMarket = MarketParams({
            loanToken: deployment.usdc,
            collateralToken: deployment.wbtc,
            oracle: deployment.wbtcOracle,
            irm: deployment.irm,
            lltv: 0.77e18
        });
        
        try manager.marketConfigs(Id.wrap(deployment.wbtcMarketId)) returns (
            bool isSupported,
            uint256,
            MarketParams memory
        ) {
            if (!isSupported) {
                manager.addMarket(wbtcMarket, 0.85e18); // 85% collateral factor
                console2.log("Added WBTC/USDC market with 85% collateral factor");
            } else {
                console2.log("WBTC/USDC market already configured");
            }
        } catch {
            manager.addMarket(wbtcMarket, 0.85e18); // 85% collateral factor
            console2.log("Added WBTC/USDC market with 85% collateral factor");
        }
        
        vm.stopBroadcast();
        
        // Save deployment addresses
        saveDeployment();
        
        console2.log("");
        console2.log("=== Portfolio Margin Deployment Complete ===");
        console2.log("PortfolioMarginManager:", deployment.portfolioMarginManager);
        console2.log("PortfolioSubAccount implementation:", deployment.portfolioSubAccountImpl);
        
        // Predict a sample sub-account address
        address sampleUser = deployer;
        address predictedSubAccount = manager.predictSubAccountAddress(sampleUser);
        console2.log("");
        console2.log("Sample sub-account for deployer:", predictedSubAccount);
    }
}