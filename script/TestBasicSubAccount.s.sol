// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {BasicSubAccount} from "../src/BasicSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestBasicSubAccountScript is Script {
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant DEPOSIT_CONTRACT = 0x5BC20A936EfEE0d758A3c168d2f017c83805B986;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Test BasicSubAccount RISEx Deposit ===");
        console2.log("Deployer:", deployer);
        console2.log("USDC balance:", IERC20(USDC).balanceOf(deployer) / 1e6, "USDC");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy BasicSubAccount
        BasicSubAccount subAccount = new BasicSubAccount(deployer);
        console2.log("Sub-account deployed at:", address(subAccount));
        
        // Fund it with 10 USDC
        uint256 fundAmount = 10e6;
        IERC20(USDC).transfer(address(subAccount), fundAmount);
        console2.log("Funded with", fundAmount / 1e6, "USDC");
        
        // Check balance
        uint256 balance = subAccount.getBalance(USDC);
        console2.log("Sub-account USDC balance:", balance / 1e6, "USDC");
        
        // Check RISEx status before deposit
        (int256 equityBefore, bool hasAccountBefore) = subAccount.checkRISExStatus();
        console2.log("RISEx equity before:", equityBefore);
        console2.log("Has RISEx account:", hasAccountBefore);
        
        // Try to deposit 5 USDC to RISEx
        uint256 depositAmount = 5e6;
        console2.log("\nAttempting to deposit", depositAmount / 1e6, "USDC to RISEx...");
        
        bool success = subAccount.depositToRISEx(depositAmount);
        console2.log("Deposit success:", success);
        
        // Check balance after
        uint256 balanceAfter = subAccount.getBalance(USDC);
        console2.log("Sub-account USDC balance after:", balanceAfter / 1e6, "USDC");
        
        // Check RISEx status after deposit
        (int256 equityAfter, bool hasAccountAfter) = subAccount.checkRISExStatus();
        console2.log("RISEx equity after:", equityAfter);
        console2.log("Has RISEx account:", hasAccountAfter);
        
        vm.stopBroadcast();
        
        console2.log("\n=== Summary ===");
        console2.log("Sub-account:", address(subAccount));
        console2.log("Deposit success:", success);
        console2.log("USDC spent:", (balance - balanceAfter) / 1e6);
        console2.log("RISEx account created:", hasAccountAfter);
    }
}