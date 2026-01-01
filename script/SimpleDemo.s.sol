// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleDemo is Script {
    // Deployed addresses
    address constant MANAGER = 0xc35a5481BB874a5d42BA02893Ec7C7a70dc03935;
    address constant TEST_SUB_ACCOUNT = 0x45525A58b161FFEC104F7F5C2e0a24c831E7E00d;
    
    // Tokens
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("\n=== Simple RISEx Deposit Demo ===");
        console2.log("Deployer:", deployer);
        console2.log("Sub-account:", TEST_SUB_ACCOUNT);
        
        // Get contracts
        PortfolioMarginManager manager = PortfolioMarginManager(MANAGER);
        PortfolioSubAccount subAccount = PortfolioSubAccount(TEST_SUB_ACCOUNT);
        
        // Check current USDC balance
        uint256 deployerUSDC = IERC20(USDC).balanceOf(deployer);
        console2.log("\nDeployer USDC balance:", deployerUSDC / 1e6);
        
        if (deployerUSDC == 0) {
            console2.log("No USDC to deposit!");
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Transfer some USDC to sub-account
        uint256 transferAmount = 100e6; // 100 USDC
        if (deployerUSDC < transferAmount) {
            transferAmount = deployerUSDC / 2; // Use half of what we have
        }
        
        console2.log("\n1. Transferring USDC to sub-account");
        IERC20(USDC).transfer(address(subAccount), transferAmount);
        console2.log("  - Transferred", transferAmount / 1e6, "USDC");
        
        // Step 2: Try to deposit to RISEx
        console2.log("\n2. Depositing to RISEx");
        uint256 risexAmount = 50e6; // 50 USDC
        if (transferAmount < risexAmount) {
            risexAmount = transferAmount / 2;
        }
        
        subAccount.depositToRISEx(risexAmount);
        console2.log("  - Attempted deposit of", risexAmount / 1e6, "USDC to RISEx");
        console2.log("  - (NotActivated error is normal - check transaction logs)");
        
        vm.stopBroadcast();
        
        // Check final state
        console2.log("\n=== Final State ===");
        
        // Check balances
        (uint256 usdcBal,,) = manager.getSubAccountBalances(deployer);
        console2.log("Sub-account USDC balance:", usdcBal / 1e6);
        
        // Check RISEx
        (int256 equity, bool hasAccount) = manager.getRISExStatus(deployer);
        console2.log("RISEx equity:", equity);
        console2.log("RISEx has account:", hasAccount);
        
        // Get transaction hash for checking
        console2.log("\nCheck transaction on explorer:");
        console2.log("https://explorer.testnet.riselabs.xyz/address/", address(subAccount));
        
        console2.log("\n=== Demo Complete ===");
    }
}