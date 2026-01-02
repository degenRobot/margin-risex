// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}

contract MintTestTokens is Script {
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    address constant MORPHO = 0x70374FB7a93fD277E66C525B93f810A7D61d5606;
    
    // WETH Market params
    address constant WETH_ORACLE = 0xe07eedf78483293348bdcd8F7495d79496F114c0;
    address constant IRM = 0xBcB3924382eF02C1235521ca63DA3071698Eab90;
    uint256 constant LLTV = 770000000000000000; // 77%
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Minting Test Tokens ===");
        console2.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Mint WETH to deployer
        console2.log("\n1. Minting 1 WETH to deployer...");
        IMintable(WETH).mint(deployer, 1 ether);
        uint256 wethBalance = IERC20(WETH).balanceOf(deployer);
        console2.log("   - WETH balance:", wethBalance / 1e18);
        
        // 2. Create a supplier account and mint USDC
        // Using a deterministic address for supplier
        address supplier = address(uint160(uint256(keccak256(abi.encodePacked(deployer, "supplier")))));
        console2.log("\n2. Setting up supplier account:", supplier);
        
        // Send some ETH for gas
        if (supplier.balance < 0.01 ether) {
            (bool sent,) = supplier.call{value: 0.01 ether}("");
            require(sent, "Failed to send ETH");
            console2.log("   - Sent 0.01 ETH for gas");
        }
        
        // Mint USDC to supplier
        console2.log("   - Minting 100k USDC to supplier...");
        IMintable(USDC).mint(supplier, 100_000e6);
        uint256 supplierUSDC = IERC20(USDC).balanceOf(supplier);
        console2.log("   - Supplier USDC balance:", supplierUSDC / 1e6);
        
        vm.stopBroadcast();
        
        console2.log("\n3. Next Steps:");
        console2.log("   - Run SupplyLiquidity script to add USDC to Morpho");
        console2.log("   - Then run TestOpenPosition to test the complete flow");
        console2.log("\nSupplier address (save this):", supplier);
    }
}