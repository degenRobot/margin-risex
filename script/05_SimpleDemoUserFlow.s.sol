// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams} from "morpho-blue/interfaces/IMorpho.sol";

/// @title SimpleDemoUserFlow
/// @notice Simple demo script showing basic portfolio margin operations
contract SimpleDemoUserFlow is Script {
    
    // Deployed addresses from testnet
    address constant MORPHO = 0x70374FB7a93fD277E66C525B93f810A7D61d5606;
    address constant PORTFOLIO_MANAGER = 0xB13Ec61327b78A024b344409D31f3e3F25eC2499;
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    address constant WETH_ORACLE = 0xe07eedf78483293348bdcd8F7495d79496F114c0;
    address constant IRM = 0xBcB3924382eF02C1235521ca63DA3071698Eab90;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);
        
        console2.log("=== Simple Portfolio Margin Demo ===");
        console2.log("User:", user);
        
        // Check if broadcasting
        bool broadcasting = vm.envOr("BROADCAST", false);
        if (broadcasting) {
            console2.log("Broadcasting transactions...");
            vm.startBroadcast(deployerPrivateKey);
        } else {
            console2.log("Running in simulation mode");
        }
        
        // Get contracts
        PortfolioMarginManager manager = PortfolioMarginManager(PORTFOLIO_MANAGER);
        
        // Check current sub-account
        address subAccount = manager.userSubAccounts(user);
        console2.log("\nChecking sub-account...");
        
        if (subAccount == address(0)) {
            console2.log("No sub-account found. Creating one...");
            subAccount = manager.createSubAccount(user);
            console2.log("Created sub-account at:", subAccount);
        } else {
            console2.log("Existing sub-account found at:", subAccount);
        }
        
        // Check RISEX address in sub-account
        console2.log("\nChecking RISEx configuration...");
        address risexAddress = address(PortfolioSubAccount(subAccount).RISEX());
        console2.log("RISEx address in sub-account:", risexAddress);
        
        if (risexAddress == address(0)) {
            console2.log("WARNING: RISEx address is 0x0 - RISEx integration will not work");
            console2.log("A new implementation with correct RISEx address needs to be deployed");
        }
        
        // Check balances
        console2.log("\nChecking token balances...");
        uint256 ethBalance = user.balance;
        
        // Try to get balances, handle proxy contracts
        uint256 usdcBalance = 0;
        uint256 wethBalance = 0;
        
        try IERC20(USDC).balanceOf(user) returns (uint256 balance) {
            usdcBalance = balance;
        } catch {
            console2.log("Could not read USDC balance");
        }
        
        try IERC20(WETH).balanceOf(user) returns (uint256 balance) {
            wethBalance = balance;
        } catch {
            console2.log("Could not read WETH balance");
        }
        
        console2.log("ETH balance:", ethBalance / 1e18, "ETH");
        console2.log("WETH balance:", wethBalance / 1e18, "WETH");
        console2.log("USDC balance:", usdcBalance / 1e6, "USDC");
        
        // Check health status
        console2.log("\nChecking portfolio health...");
        if (risexAddress != address(0)) {
            try manager.getPortfolioHealth(user) returns (PortfolioMarginManager.HealthStatus memory health) {
                console2.log("Collateral value: $", health.totalCollateralValue / 1e6);
                console2.log("Debt value: $", health.totalDebtValue / 1e6);
                console2.log("Health factor:", health.healthFactor == type(uint256).max ? "Infinite" : string(abi.encodePacked(uint2str(health.healthFactor * 100 / 1e18), "%")));
                console2.log("Is healthy:", health.isHealthy);
            } catch {
                console2.log("Could not get portfolio health (expected with RISEx at 0x0)");
            }
        } else {
            console2.log("Skipping health check due to RISEx address being 0x0");
            console2.log("Health check requires RISEx integration to be functional");
        }
        
        // Summary
        console2.log("\n=== Summary ===");
        console2.log("Sub-account:", subAccount);
        console2.log("USDC available:", usdcBalance / 1e6, "USDC");
        console2.log("Can deposit ETH to get WETH for collateral");
        console2.log("\nNext steps:");
        console2.log("1. Get WETH by sending ETH to WETH contract");
        console2.log("2. Approve and deposit WETH as collateral");
        console2.log("3. Borrow USDC against collateral");
        console2.log("4. Deploy new implementation with RISEx address for trading");
        
        if (broadcasting) {
            vm.stopBroadcast();
        }
    }
    
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}