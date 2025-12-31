// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDC {
    function mint(address to, uint256 amount) external;
}

/// @title TestUSDCMint
/// @notice Test USDC minting on RISE testnet (not in fork mode)
contract TestUSDCMint is Script {
    
    IERC20 constant USDC = IERC20(0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Testing USDC Mint ===");
        console2.log("Deployer:", deployer);
        
        // Check initial balance
        uint256 initialBalance = USDC.balanceOf(deployer);
        console2.log("Initial USDC balance:", initialBalance / 1e6, "USDC");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Mint 10k USDC
        uint256 mintAmount = 10_000e6;
        console2.log("\nMinting", mintAmount / 1e6, "USDC...");
        
        IUSDC(address(USDC)).mint(deployer, mintAmount);
        
        vm.stopBroadcast();
        
        // Check final balance
        uint256 finalBalance = USDC.balanceOf(deployer);
        console2.log("\nFinal USDC balance:", finalBalance / 1e6, "USDC");
        console2.log("Minted:", (finalBalance - initialBalance) / 1e6, "USDC");
        
        if (finalBalance > initialBalance) {
            console2.log("\n[SUCCESS] USDC minting works!");
        } else {
            console2.log("\n[FAILED] USDC minting did not increase balance");
        }
    }
}