// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";

/// @title TestWithdrawal
/// @notice Test withdrawal functionality - repay debt and withdraw collateral
contract TestWithdrawal is Script {
    // Deployed addresses
    address constant MANAGER = 0xc35a5481BB874a5d42BA02893Ec7C7a70dc03935;
    address constant TEST_SUB_ACCOUNT = 0x45525A58b161FFEC104F7F5C2e0a24c831E7E00d;
    
    // Tokens
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("\n=== Testing Withdrawal Flow ===");
        console2.log("Deployer:", deployer);
        console2.log("Sub-account:", TEST_SUB_ACCOUNT);
        
        // Get contracts
        PortfolioMarginManager manager = PortfolioMarginManager(MANAGER);
        PortfolioSubAccount subAccount = PortfolioSubAccount(TEST_SUB_ACCOUNT);
        
        // Check initial state
        console2.log("\n1. Checking current positions...");
        (uint256 totalColValue, uint256 totalDebtValue) = manager.getMorphoValues(deployer);
        console2.log("   - Collateral Value:", totalColValue / 1e6, "USDC");
        console2.log("   - Debt Value:", totalDebtValue / 1e6, "USDC");
        
        (uint256 usdcBal, uint256 wethBal,) = manager.getSubAccountBalances(deployer);
        console2.log("   - Sub-account USDC:", usdcBal / 1e6);
        console2.log("   - Sub-account WETH:", wethBal / 1e18);
        
        // Get market params
        (MarketParams memory wethMarket,) = manager.getMarketParams();
        
        // If we have debt, try to repay it
        if (totalDebtValue > 0) {
            console2.log("\n2. Attempting to repay debt...");
            
            // Check if we have USDC in the sub-account to repay
            if (usdcBal >= totalDebtValue) {
                vm.startBroadcast(deployerPrivateKey);
                
                // Repay all debt
                subAccount.repayToMorpho(wethMarket, type(uint256).max);
                console2.log("   - Repaid all debt");
                
                vm.stopBroadcast();
            } else {
                console2.log("   - Insufficient USDC to repay debt");
                console2.log("   - Need", (totalDebtValue - usdcBal) / 1e6, "more USDC");
                
                // Try to get USDC from deployer
                uint256 deployerUSDC = IERC20(USDC).balanceOf(deployer);
                if (deployerUSDC >= (totalDebtValue - usdcBal)) {
                    vm.startBroadcast(deployerPrivateKey);
                    
                    // Approve and repay
                    IERC20(USDC).approve(address(subAccount), totalDebtValue);
                    subAccount.repayToMorpho(wethMarket, totalDebtValue);
                    console2.log("   - Repaid debt using deployer's USDC");
                    
                    vm.stopBroadcast();
                }
            }
        }
        
        // Check if we have collateral to withdraw
        console2.log("\n3. Checking collateral after repayment...");
        (uint256 wethCol,,,) = manager.getMorphoPositions(deployer);
        
        if (wethCol > 0) {
            console2.log("   - WETH collateral:", wethCol / 1e18);
            
            // Check debt again
            (, totalDebtValue) = manager.getMorphoValues(deployer);
            
            if (totalDebtValue == 0) {
                console2.log("\n4. Withdrawing collateral...");
                
                vm.startBroadcast(deployerPrivateKey);
                
                // Withdraw all collateral to deployer
                subAccount.withdrawFromMorpho(wethMarket, wethCol, deployer);
                console2.log("   - Withdrew", wethCol / 1e18, "WETH to deployer");
                
                vm.stopBroadcast();
            } else {
                console2.log("   - Cannot withdraw - still have debt:", totalDebtValue / 1e6, "USDC");
            }
        } else {
            console2.log("   - No collateral to withdraw");
        }
        
        // Final state
        console2.log("\n5. Final state:");
        (totalColValue, totalDebtValue) = manager.getMorphoValues(deployer);
        console2.log("   - Collateral Value:", totalColValue / 1e6, "USDC");
        console2.log("   - Debt Value:", totalDebtValue / 1e6, "USDC");
        
        uint256 deployerWETH = IERC20(WETH).balanceOf(deployer);
        console2.log("   - Deployer WETH:", deployerWETH / 1e18);
        
        console2.log("\n=== Withdrawal Test Complete ===");
    }
}