// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {BasicSubAccount} from "../src/BasicSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestDirectSubAccountDepositScript is Script {
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Test BasicSubAccount with Direct PerpsManager Deposit ===");
        console2.log("Deployer:", deployer);
        console2.log("USDC balance:", IERC20(USDC).balanceOf(deployer) / 1e6, "USDC");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new BasicSubAccount
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
        console2.log("\nBefore deposit:");
        console2.log("- RISEx equity:", equityBefore);
        console2.log("- Has RISEx account:", hasAccountBefore);
        
        // Deposit 5 USDC to RISEx using direct PerpsManager deposit
        uint256 depositAmount = 5e6;
        console2.log("\nDepositing", depositAmount / 1e6, "USDC to RISEx via PerpsManager...");
        
        bool success = subAccount.depositToRISEx(depositAmount);
        console2.log("Deposit success:", success);
        
        vm.stopBroadcast();
        
        // Check final state
        uint256 finalBalance = subAccount.getBalance(USDC);
        (int256 equityAfter, bool hasAccountAfter) = subAccount.checkRISExStatus();
        
        console2.log("\nAfter deposit:");
        console2.log("- Sub-account USDC balance:", finalBalance / 1e6, "USDC");
        console2.log("- RISEx equity:", equityAfter);
        console2.log("- RISEx equity in USDC:", uint256(equityAfter) / 1e18);
        console2.log("- Has RISEx account:", hasAccountAfter);
        
        console2.log("\n=== Summary ===");
        console2.log("Sub-account address:", address(subAccount));
        if (success && finalBalance == 5e6 && equityAfter == 5e18) {
            console2.log("SUCCESS: Direct PerpsManager deposit worked correctly!");
            console2.log("- 5 USDC deposited to RISEx");
            console2.log("- 5 USDC remaining in sub-account");
        } else if (!success) {
            console2.log("FAILED: Deposit was not successful");
        } else {
            console2.log("PARTIAL: Deposit may have worked but state is unexpected");
        }
    }
}