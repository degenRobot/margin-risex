// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";

interface IUSDC {
    function decimals() external view returns (uint8);
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract MintUSDCScript is Script {
    // RISE testnet USDC
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    
    function run() public {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Minting USDC to:", deployer);
        console2.log("USDC address:", USDC);
        
        // Check balance before
        uint256 balanceBefore = IUSDC(USDC).balanceOf(deployer);
        console2.log("Balance before:", balanceBefore / 1e6, "USDC");
        
        // Start broadcast
        vm.startBroadcast(deployerPrivateKey);
        
        // Mint 1M USDC (max allowed per mint)
        uint256 mintAmount = 1_000_000 * 1e6; // 1M USDC
        
        console2.log("Minting amount:", mintAmount / 1e6, "USDC");
        
        IUSDC(USDC).mint(deployer, mintAmount);
        
        vm.stopBroadcast();
        
        // Check balance after
        uint256 balanceAfter = IUSDC(USDC).balanceOf(deployer);
        console2.log("Balance after:", balanceAfter / 1e6, "USDC");
        console2.log("Successfully minted", mintAmount / 1e6, "USDC");
    }
}