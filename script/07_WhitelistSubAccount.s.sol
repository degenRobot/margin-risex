// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {IWhitelist} from "../src/interfaces/IRISExPerpsManager.sol";

/// @title Whitelist SubAccount Script
/// @notice Whitelist a sub-account on RISEx for trading
contract WhitelistSubAccountScript is Script {
    // RISEx Whitelist contract
    address constant WHITELIST = 0x5b2Fcc7C1efC8f8D9968a5de2F51063984db41E5;
    
    function run() external {
        // Get the sub-account address from command line or environment
        address subAccount = vm.envOr("SUB_ACCOUNT", address(0));
        require(subAccount != address(0), "SUB_ACCOUNT not set");
        
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set");
        
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Requesting whitelist for sub-account:", subAccount);
        console2.log("From:", deployer);
        
        IWhitelist whitelist = IWhitelist(WHITELIST);
        
        // Check if already whitelisted
        bool isWhitelisted = whitelist.isWhitelisted(subAccount);
        console2.log("Current whitelist status:", isWhitelisted);
        
        if (isWhitelisted) {
            console2.log("Sub-account is already whitelisted!");
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Request whitelist access
        console2.log("Requesting whitelist access...");
        whitelist.requestWhitelistAccess(subAccount);
        
        vm.stopBroadcast();
        
        // Check status again
        isWhitelisted = whitelist.isWhitelisted(subAccount);
        console2.log("New whitelist status:", isWhitelisted);
        
        if (isWhitelisted) {
            console2.log("Sub-account successfully whitelisted!");
        } else {
            console2.log("Whitelist request submitted. May need approval from RISEx team.");
            console2.log("Check status later with: cast call", WHITELIST, "isWhitelisted(address)", subAccount);
        }
    }
}