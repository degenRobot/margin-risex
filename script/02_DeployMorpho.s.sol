// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseDeployment} from "./BaseDeployment.s.sol";
import {Morpho, Id, MarketParams, Market} from "morpho-blue/Morpho.sol";
import {MarketParamsLib} from "morpho-blue/libraries/MarketParamsLib.sol";
import {console2} from "forge-std/console2.sol";

/// @title DeployMorpho
/// @notice Deploy Morpho Blue and create lending markets
contract DeployMorpho is BaseDeployment {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Deploying Morpho Blue ===");
        console2.log("Deployer:", deployer);
        console2.log("");
        
        // Load existing deployment
        loadDeployment();
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Morpho Blue
        if (deployment.morpho == address(0)) {
            deployment.morpho = address(new Morpho(deployer));
            console2.log("Morpho Blue deployed at:", deployment.morpho);
        } else {
            console2.log("Morpho Blue already deployed at:", deployment.morpho);
        }
        
        // Enable IRM and oracles
        Morpho morpho = Morpho(deployment.morpho);
        
        // Enable IRM if not already enabled
        if (!morpho.isIrmEnabled(deployment.irm)) {
            morpho.enableIrm(deployment.irm);
            console2.log("Enabled IRM:", deployment.irm);
        }
        
        // Enable LLTV values for markets
        uint256 wethLltv = 0.77e18; // 77% LTV
        uint256 wbtcLltv = 0.77e18; // 77% LTV
        
        if (!morpho.isLltvEnabled(wethLltv)) {
            morpho.enableLltv(wethLltv);
            console2.log("Enabled LLTV:", wethLltv);
        }
        
        if (!morpho.isLltvEnabled(wbtcLltv)) {
            morpho.enableLltv(wbtcLltv);
            console2.log("Enabled LLTV:", wbtcLltv);
        }
        
        // Create WETH/USDC market
        MarketParams memory wethMarket = MarketParams({
            loanToken: deployment.usdc,
            collateralToken: deployment.weth,
            oracle: deployment.wethOracle,
            irm: deployment.irm,
            lltv: wethLltv
        });
        
        Id wethMarketId = MarketParamsLib.id(wethMarket);
        
        // Check if market already exists
        (uint128 totalSupplyAssets, , , , uint128 lastUpdate, ) = morpho.market(wethMarketId);
        if (lastUpdate == 0) {
            morpho.createMarket(wethMarket);
            console2.log("Created WETH/USDC market");
            console2.log("  Market ID:", vm.toString(bytes32(Id.unwrap(wethMarketId))));
        } else {
            console2.log("WETH/USDC market already exists");
        }
        deployment.wethMarketId = Id.unwrap(wethMarketId);
        
        // Create WBTC/USDC market
        MarketParams memory wbtcMarket = MarketParams({
            loanToken: deployment.usdc,
            collateralToken: deployment.wbtc,
            oracle: deployment.wbtcOracle,
            irm: deployment.irm,
            lltv: wbtcLltv
        });
        
        Id wbtcMarketId = MarketParamsLib.id(wbtcMarket);
        
        // Check if market already exists
        (uint128 totalSupplyAssetsWbtc, , , , uint128 lastUpdateWbtc, ) = morpho.market(wbtcMarketId);
        if (lastUpdateWbtc == 0) {
            morpho.createMarket(wbtcMarket);
            console2.log("Created WBTC/USDC market");
            console2.log("  Market ID:", vm.toString(bytes32(Id.unwrap(wbtcMarketId))));
        } else {
            console2.log("WBTC/USDC market already exists");
        }
        deployment.wbtcMarketId = Id.unwrap(wbtcMarketId);
        
        vm.stopBroadcast();
        
        // Save deployment addresses
        saveDeployment();
        
        console2.log("");
        console2.log("=== Morpho Deployment Complete ===");
        console2.log("Morpho Blue:", deployment.morpho);
        console2.log("WETH Market ID:", vm.toString(deployment.wethMarketId));
        console2.log("WBTC Market ID:", vm.toString(deployment.wbtcMarketId));
    }
}