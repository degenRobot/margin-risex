// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {MorphoAdapter} from "../src/adapters/MorphoAdapter.sol";
import {Constants} from "../src/libraries/Constants.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";

/// @title DeployFull
/// @notice Deploy the complete portfolio margin system
contract DeployFull is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deploying from:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy PortfolioMarginManager
        console2.log("Deploying PortfolioMarginManager...");
        PortfolioMarginManager manager = new PortfolioMarginManager();
        console2.log("Manager deployed at:", address(manager));
        
        // Create a sub-account for the deployer to test
        console2.log("\nCreating sub-account for deployer...");
        address subAccount = manager.createSubAccount(deployer);
        console2.log("Sub-account created at:", subAccount);
        
        // Log important addresses
        console2.log("\n=== Deployment Summary ===");
        console2.log("PortfolioMarginManager:", address(manager));
        console2.log("MorphoAdapter:", address(manager.morphoAdapter()));
        console2.log("Deployer Sub-Account:", subAccount);
        
        console2.log("\n=== External Protocol Addresses ===");
        console2.log("Morpho Blue:", Constants.MORPHO);
        console2.log("RISEx PerpsManager:", Constants.RISEX_PERPS_MANAGER);
        console2.log("USDC:", Constants.USDC);
        console2.log("WETH:", Constants.WETH);
        console2.log("WBTC:", Constants.WBTC);
        
        vm.stopBroadcast();
        
        // Write deployment info to file for future reference
        _writeDeploymentInfo(address(manager), subAccount);
    }
    
    function _writeDeploymentInfo(address manager, address subAccount) private {
        string memory json = string.concat(
            "{\n",
            '  "network": "rise-testnet",\n',
            '  "chainId": 11155931,\n',
            '  "contracts": {\n',
            '    "PortfolioMarginManager": "', vm.toString(manager), '",\n',
            '    "TestSubAccount": "', vm.toString(subAccount), '"\n',
            '  },\n',
            '  "timestamp": ', vm.toString(block.timestamp), '\n',
            "}"
        );
        
        string memory path = string.concat("deployments/", vm.toString(block.chainid), "-latest.json");
        vm.writeFile(path, json);
        console2.log("\nDeployment info written to:", path);
    }
}