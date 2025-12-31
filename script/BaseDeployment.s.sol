// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

/// @title BaseDeployment
/// @notice Base contract for deployment scripts with address management
abstract contract BaseDeployment is Script {
    
    struct Deployment {
        address deployer;
        uint256 chainId;
        address weth;
        address wbtc;
        address usdc;
        address wethOracle;
        address wbtcOracle;
        address irm;
        address morpho;
        bytes32 wethMarketId;
        bytes32 wbtcMarketId;
        address portfolioMarginManager;
        address portfolioSubAccountImpl;
    }
    
    Deployment public deployment;
    
    /// @notice Load deployment addresses from JSON file
    function loadDeployment() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", vm.toString(block.chainid), ".json");
        
        if (vm.exists(path)) {
            string memory json = vm.readFile(path);
            deployment.deployer = vm.parseJsonAddress(json, ".deployer");
            deployment.chainId = vm.parseJsonUint(json, ".chainId");
            deployment.weth = vm.parseJsonAddress(json, ".weth");
            deployment.wbtc = vm.parseJsonAddress(json, ".wbtc");
            deployment.usdc = vm.parseJsonAddress(json, ".usdc");
            deployment.wethOracle = vm.parseJsonAddress(json, ".wethOracle");
            deployment.wbtcOracle = vm.parseJsonAddress(json, ".wbtcOracle");
            deployment.irm = vm.parseJsonAddress(json, ".irm");
            deployment.morpho = vm.parseJsonAddress(json, ".morpho");
            deployment.wethMarketId = vm.parseJsonBytes32(json, ".wethMarketId");
            deployment.wbtcMarketId = vm.parseJsonBytes32(json, ".wbtcMarketId");
            deployment.portfolioMarginManager = vm.parseJsonAddress(json, ".portfolioMarginManager");
            deployment.portfolioSubAccountImpl = vm.parseJsonAddress(json, ".portfolioSubAccountImpl");
        }
    }
    
    /// @notice Save deployment addresses to JSON file
    function saveDeployment() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", vm.toString(block.chainid), ".json");
        
        string memory json = "deployment";
        vm.serializeAddress(json, "deployer", deployment.deployer);
        vm.serializeUint(json, "chainId", deployment.chainId);
        vm.serializeAddress(json, "weth", deployment.weth);
        vm.serializeAddress(json, "wbtc", deployment.wbtc);
        vm.serializeAddress(json, "usdc", deployment.usdc);
        vm.serializeAddress(json, "wethOracle", deployment.wethOracle);
        vm.serializeAddress(json, "wbtcOracle", deployment.wbtcOracle);
        vm.serializeAddress(json, "irm", deployment.irm);
        vm.serializeAddress(json, "morpho", deployment.morpho);
        vm.serializeBytes32(json, "wethMarketId", deployment.wethMarketId);
        vm.serializeBytes32(json, "wbtcMarketId", deployment.wbtcMarketId);
        vm.serializeAddress(json, "portfolioMarginManager", deployment.portfolioMarginManager);
        string memory finalJson = vm.serializeAddress(json, "portfolioSubAccountImpl", deployment.portfolioSubAccountImpl);
        
        vm.writeJson(finalJson, path);
    }
    
    /// @notice Log deployment info
    function logDeployment(string memory name, address addr) internal {
        console2.log(string.concat(name, " deployed at:"), addr);
    }
}