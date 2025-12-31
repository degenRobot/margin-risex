// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseDeployment} from "./BaseDeployment.s.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {MockWETH} from "../src/mocks/MockWETH.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams, Position, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {console2} from "forge-std/console2.sol";

/// @title DemoUserFlow
/// @notice Demonstrates the complete user flow for portfolio margin
contract DemoUserFlow is BaseDeployment {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(deployerPrivateKey);
        
        console2.log("=== Portfolio Margin Demo ===");
        console2.log("User:", user);
        console2.log("");
        
        // Load deployment
        loadDeployment();
        
        // Get contracts
        PortfolioMarginManager manager = PortfolioMarginManager(deployment.portfolioMarginManager);
        IMorpho morpho = IMorpho(deployment.morpho);
        MockWETH weth = MockWETH(payable(deployment.weth));
        MockUSDC usdc = MockUSDC(payable(deployment.usdc));
        
        // Market params
        MarketParams memory wethMarket = MarketParams({
            loanToken: deployment.usdc,
            collateralToken: deployment.weth,
            oracle: deployment.wethOracle,
            irm: deployment.irm,
            lltv: 0.77e18
        });
        
        // Start broadcasting if we have a private key
        bool broadcasting = vm.envOr("BROADCAST", false);
        if (broadcasting) {
            vm.startBroadcast(deployerPrivateKey);
            console2.log("Broadcasting transactions...");
        } else {
            console2.log("Running in simulation mode (set BROADCAST=true to execute)");
        }
        
        // Step 1: Get some test tokens
        console2.log("");
        console2.log("Step 1: Getting test tokens...");
        
        // Check initial balances
        uint256 wethBalance = weth.balanceOf(user);
        uint256 usdcBalance = usdc.balanceOf(user);
        
        console2.log("");
        console2.log("Current balances:");
        console2.log("WETH:", wethBalance / 1e18, "WETH");
        console2.log("USDC:", usdcBalance / 1e6, "USDC");
        
        // Check WETH balance
        if (wethBalance == 0) {
            console2.log("");
            console2.log("No WETH balance. Getting some WETH...");
            
            // Check ETH balance
            uint256 ethBalance = user.balance;
            console2.log("ETH balance:", ethBalance / 1e18, "ETH");
            
            if (ethBalance < 5e18) {
                console2.log("Insufficient ETH balance. Need at least 5 ETH to continue.");
                return;
            }
            
            // Deposit ETH to get WETH (using receive function)
            (bool success,) = payable(address(weth)).call{value: 5e18}("");
            require(success, "ETH deposit failed");
            wethBalance = weth.balanceOf(user);
            console2.log("Deposited 5 ETH to get", wethBalance / 1e18, "WETH");
        }
        
        // Step 2: Create sub-account
        console2.log("");
        console2.log("Step 2: Creating sub-account...");
        
        address subAccount = manager.userSubAccounts(user);
        if (subAccount == address(0)) {
            subAccount = manager.createSubAccount(user);
            console2.log("Created sub-account at:", subAccount);
        } else {
            console2.log("Using existing sub-account:", subAccount);
        }
        
        // Step 3: Deposit collateral
        console2.log("");
        console2.log("Step 3: Depositing collateral...");
        
        uint256 depositAmount = 5e18; // 5 WETH
        weth.approve(subAccount, depositAmount);
        PortfolioSubAccount(subAccount).depositCollateral(wethMarket, depositAmount);
        console2.log("Deposited 5 WETH as collateral");
        
        // Check Morpho position
        Position memory position = morpho.position(Id.wrap(deployment.wethMarketId), subAccount);
        console2.log("Morpho collateral:", position.collateral / 1e18, "WETH");
        
        // Step 4: Check health
        console2.log("");
        console2.log("Step 4: Checking portfolio health...");
        
        PortfolioMarginManager.HealthStatus memory health = manager.getPortfolioHealth(user);
        console2.log("Collateral value: $", health.totalCollateralValue / 1e6);
        console2.log("Debt value: $", health.totalDebtValue / 1e6);
        console2.log("RISEx equity: $", int256(health.risexEquity) / 1e6);
        console2.log("Health factor:", health.healthFactor * 100 / 1e18, "%");
        console2.log("Is healthy:", health.isHealthy);
        
        // Step 5: Borrow USDC
        console2.log("");
        console2.log("Step 5: Borrowing USDC...");
        
        uint256 borrowAmount = 5000e6; // $5k USDC
        PortfolioSubAccount(subAccount).borrowUSDC(wethMarket, borrowAmount);
        console2.log("Borrowed $5k USDC");
        
        // Check updated health
        health = manager.getPortfolioHealth(user);
        console2.log("");
        console2.log("Updated health:");
        console2.log("Collateral value: $", health.totalCollateralValue / 1e6);
        console2.log("Debt value: $", health.totalDebtValue / 1e6);
        console2.log("Health factor:", health.healthFactor * 100 / 1e18, "%");
        
        // Step 6: Deposit to RISEx (will fail with current deployment)
        console2.log("");
        console2.log("Step 6: RISEx integration...");
        console2.log("Note: RISEx integration requires updating sub-account implementation");
        console2.log("Current RISEx address in sub-account:", address(PortfolioSubAccount(subAccount).RISEX()));
        
        if (broadcasting) {
            vm.stopBroadcast();
        }
        
        console2.log("");
        console2.log("=== Demo Complete ===");
        console2.log("");
        console2.log("Summary:");
        console2.log("- Created/used sub-account at:", subAccount);
        console2.log("- Deposited 5 WETH as collateral");
        console2.log("- Borrowed $5k USDC");
        console2.log("- Health factor:", health.healthFactor * 100 / 1e18, "%");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Deploy new PortfolioSubAccount implementation with RISEx address");
        console2.log("2. Use borrowed USDC for RISEx perp trading");
        console2.log("3. Monitor cross-protocol health factor");
    }
}