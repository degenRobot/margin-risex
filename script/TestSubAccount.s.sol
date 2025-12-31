// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";

/// @title TestSubAccount
/// @notice Test sub-account creation on deployed contracts
contract TestSubAccount is Script {
    
    PortfolioMarginManager constant MANAGER = PortfolioMarginManager(0x393F1532F2207DE1AFc3Fff43ddBA1344eE63855);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Testing Sub-Account Creation ===");
        console2.log("Deployer:", deployer);
        console2.log("Manager:", address(MANAGER));
        
        // Check if sub-account already exists
        address existingSubAccount = MANAGER.userSubAccounts(deployer);
        console2.log("\nExisting sub-account:", existingSubAccount);
        
        if (existingSubAccount != address(0)) {
            console2.log("Sub-account already exists!");
            
            // Verify details
            PortfolioSubAccount subAccount = PortfolioSubAccount(existingSubAccount);
            console2.log("\nSub-account details:");
            console2.log("- User:", subAccount.user());
            console2.log("- Manager:", subAccount.MANAGER());
            console2.log("- Morpho:", address(subAccount.MORPHO()));
            console2.log("- RISEx:", address(subAccount.RISEX()));
            
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create new sub-account
        console2.log("\nCreating new sub-account...");
        address newSubAccount = MANAGER.createSubAccount(deployer);
        
        vm.stopBroadcast();
        
        console2.log("\n[SUCCESS] Sub-account created at:", newSubAccount);
        
        // Verify creation
        PortfolioSubAccount subAccount = PortfolioSubAccount(newSubAccount);
        console2.log("\nSub-account details:");
        console2.log("- User:", subAccount.user());
        console2.log("- Manager:", subAccount.MANAGER());
        console2.log("- Morpho:", address(subAccount.MORPHO()));
        console2.log("- RISEx:", address(subAccount.RISEX()));
        
        // Check health
        PortfolioMarginManager.HealthStatus memory health = MANAGER.getPortfolioHealth(deployer);
        console2.log("\nInitial health status:");
        console2.log("- Is healthy:", health.isHealthy);
        console2.log("- Collateral value:", health.totalCollateralValue);
        console2.log("- Debt value:", health.totalDebtValue);
    }
}