// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {BasicSubAccount} from "../src/BasicSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPerpsManager {
    function getAccountEquity(address account) external view returns (int256);
}

contract CheckDeployedSubAccountScript is Script {
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    
    // Our deployed sub-account
    address constant SUB_ACCOUNT = 0xee5BA9601fa04124afA42b4BC39D167D8B754e75;
    
    function run() public view {
        console2.log("=== Check Deployed SubAccount Status ===");
        console2.log("Sub-account:", SUB_ACCOUNT);
        console2.log("");
        
        // Check USDC balance
        uint256 usdcBalance = IERC20(USDC).balanceOf(SUB_ACCOUNT);
        console2.log("USDC balance:", usdcBalance / 1e6, "USDC");
        console2.log("USDC balance (raw):", usdcBalance);
        
        // Check RISEx account equity
        console2.log("\nChecking RISEx status...");
        try IPerpsManager(PERPS_MANAGER).getAccountEquity(SUB_ACCOUNT) returns (int256 equity) {
            console2.log("RISEx account equity:", equity);
            console2.log("RISEx account exists: true");
            
            if (equity > 0) {
                console2.log("Equity in USDC:", uint256(equity) / 1e18, "USDC");
            }
        } catch {
            console2.log("RISEx account exists: false");
        }
        
        // Check our test account balance to see if USDC was spent
        address testAccount = 0x8E2f075B24Fd64f3E4d0ccab1ade2646AdA9ABAb;
        uint256 testAccountBalance = IERC20(USDC).balanceOf(testAccount);
        console2.log("\nTest account USDC balance:", testAccountBalance / 1e6, "USDC");
        
        console2.log("\n=== Analysis ===");
        if (usdcBalance == 10e6) {
            console2.log("All USDC still in sub-account - deposit failed");
        } else if (usdcBalance == 5e6) {
            console2.log("5 USDC deposited successfully but RISEx call reverted");
        } else {
            console2.log("Unexpected balance state");
        }
    }
}