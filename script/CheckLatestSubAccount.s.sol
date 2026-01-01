// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPerpsManager {
    function getAccountEquity(address account) external view returns (int256);
}

contract CheckLatestSubAccountScript is Script {
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    
    // Latest deployed sub-account from logs
    address constant SUB_ACCOUNT = 0xE6Fa695fC26E92fb10a1b0228458F86a0E1A5184;
    
    function run() public view {
        console2.log("=== Check Latest SubAccount Status ===");
        console2.log("Sub-account:", SUB_ACCOUNT);
        console2.log("");
        
        // Check USDC balance
        uint256 usdcBalance = IERC20(USDC).balanceOf(SUB_ACCOUNT);
        console2.log("USDC balance:", usdcBalance / 1e6, "USDC");
        console2.log("USDC balance (raw):", usdcBalance);
        
        // Check RISEx account equity
        console2.log("\nChecking RISEx status...");
        try IPerpsManager(PERPS_MANAGER).getAccountEquity(SUB_ACCOUNT) returns (int256 equity) {
            console2.log("RISEx account equity (raw):", equity);
            console2.log("RISEx account equity (USDC):", uint256(equity) / 1e18);
            console2.log("RISEx account exists: true");
        } catch {
            console2.log("RISEx account exists: false");
        }
        
        console2.log("\n=== Analysis ===");
        console2.log("Expected: 5 USDC in sub-account, 5 USDC in RISEx");
        console2.log("The deposit transaction logs show USDC transfers happened");
        console2.log("But the contract reverted with NotActivated");
        console2.log("This suggests the deposit worked but something else failed");
    }
}