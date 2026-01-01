// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TestRISExWithdrawal
/// @notice Test withdrawing USDC from RISEx back to sub-account
contract TestRISExWithdrawal is Script {
    // Deployed addresses
    address constant MANAGER = 0xc35a5481BB874a5d42BA02893Ec7C7a70dc03935;
    address constant TEST_SUB_ACCOUNT = 0x45525A58b161FFEC104F7F5C2e0a24c831E7E00d;
    
    // Tokens
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("\n=== Testing RISEx Withdrawal ===");
        console2.log("Deployer:", deployer);
        console2.log("Sub-account:", TEST_SUB_ACCOUNT);
        
        // Get contracts
        PortfolioMarginManager manager = PortfolioMarginManager(MANAGER);
        PortfolioSubAccount subAccount = PortfolioSubAccount(TEST_SUB_ACCOUNT);
        
        // Check RISEx status
        console2.log("\n1. Checking RISEx status...");
        (int256 equity, bool hasAccount) = manager.getRISExStatus(deployer);
        console2.log("   - RISEx Equity:", equity);
        console2.log("   - Has Account:", hasAccount);
        
        // Check current balances
        (uint256 usdcBal,,) = manager.getSubAccountBalances(deployer);
        console2.log("   - Sub-account USDC before:", usdcBal / 1e6);
        
        if (hasAccount && equity > 0) {
            console2.log("\n2. Attempting RISEx withdrawal...");
            
            vm.startBroadcast(deployerPrivateKey);
            
            // Try to withdraw some USDC
            uint256 withdrawAmount = 10e6; // Try 10 USDC
            if (uint256(equity) >= withdrawAmount) {
                try subAccount.withdrawFromRISEx(address(USDC), withdrawAmount) {
                    console2.log("   - Withdrawal successful!");
                } catch Error(string memory reason) {
                    console2.log("   - Withdrawal failed:", reason);
                } catch {
                    console2.log("   - Withdrawal failed (no reason)");
                }
            } else {
                // Try to withdraw all
                try subAccount.withdrawFromRISEx(address(USDC), type(uint256).max) {
                    console2.log("   - Withdrew all available USDC");
                } catch {
                    console2.log("   - Withdrawal failed");
                }
            }
            
            vm.stopBroadcast();
            
            // Check balance after
            console2.log("\n3. Checking final balances...");
            (usdcBal,,) = manager.getSubAccountBalances(deployer);
            console2.log("   - Sub-account USDC after:", usdcBal / 1e6);
            
            // Check RISEx equity after
            (equity, hasAccount) = manager.getRISExStatus(deployer);
            console2.log("   - RISEx Equity after:", equity);
        } else {
            console2.log("   - No RISEx equity to withdraw");
        }
        
        console2.log("\n=== RISEx Withdrawal Test Complete ===");
        console2.log("Note: RISEx withdrawals may fail with NotActivated on testnet");
        console2.log("Check transaction logs for actual behavior");
    }
}