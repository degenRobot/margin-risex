// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";

// Interface for WETH (WETH9 style)
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract FullDemo is Script {
    // Deployed addresses
    address constant MANAGER = 0xc35a5481BB874a5d42BA02893Ec7C7a70dc03935;
    address constant TEST_SUB_ACCOUNT = 0x45525A58b161FFEC104F7F5C2e0a24c831E7E00d;
    
    // Tokens
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("\n=== Full Portfolio Margin Demo ===");
        console2.log("Deployer:", deployer);
        console2.log("Manager:", MANAGER);
        console2.log("Sub-account:", TEST_SUB_ACCOUNT);
        
        // Get contracts
        PortfolioMarginManager manager = PortfolioMarginManager(MANAGER);
        PortfolioSubAccount subAccount = PortfolioSubAccount(TEST_SUB_ACCOUNT);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Get some WETH by depositing ETH
        uint256 ethBalance = deployer.balance;
        console2.log("\n1. Getting WETH");
        console2.log("  - ETH balance:", ethBalance / 1e18);
        
        uint256 wethAmount = 0.01e18; // 0.01 ETH worth
        if (ethBalance >= wethAmount) {
            IWETH(WETH).deposit{value: wethAmount}();
            console2.log("  - Deposited", wethAmount / 1e18, "ETH to get WETH");
        } else {
            console2.log("  - Insufficient ETH balance");
            vm.stopBroadcast();
            return;
        }
        
        // Step 2: Deposit WETH as collateral
        console2.log("\n2. Depositing WETH as collateral");
        IERC20(WETH).approve(address(subAccount), wethAmount);
        
        // Get market params
        (MarketParams memory wethMarket,) = manager.getMarketParams();
        
        // Supply to Morpho
        subAccount.supplyToMorpho(wethMarket, wethAmount);
        console2.log("  - Supplied", wethAmount / 1e18, "WETH to Morpho");
        
        // Step 3: Borrow USDC
        console2.log("\n3. Borrowing USDC");
        uint256 borrowAmount = 10e6; // 10 USDC (conservative)
        subAccount.borrowFromMorpho(wethMarket, borrowAmount);
        console2.log("  - Borrowed", borrowAmount / 1e6, "USDC");
        
        // Step 4: Try to deposit to RISEx
        console2.log("\n4. Depositing to RISEx");
        uint256 risexAmount = 5e6; // 5 USDC
        subAccount.depositToRISEx(risexAmount);
        console2.log("  - Attempted deposit of", risexAmount / 1e6, "USDC to RISEx");
        console2.log("  - (NotActivated error is normal - check logs)");
        
        vm.stopBroadcast();
        
        // Check final state
        console2.log("\n=== Final State ===");
        
        // Check balances
        (uint256 usdcBal, uint256 wethBal,) = manager.getSubAccountBalances(deployer);
        console2.log("Sub-account balances:");
        console2.log("  - USDC:", usdcBal / 1e6);
        console2.log("  - WETH:", wethBal / 1e18);
        
        // Check Morpho positions
        (uint256 totalColValue, uint256 totalDebtValue) = manager.getMorphoValues(deployer);
        console2.log("\nMorpho position:");
        console2.log("  - Collateral Value:", totalColValue / 1e6, "USDC");
        console2.log("  - Debt Value:", totalDebtValue / 1e6, "USDC");
        
        // Check RISEx
        (int256 equity, bool hasAccount) = manager.getRISExStatus(deployer);
        console2.log("\nRISEx status:");
        console2.log("  - Equity:", equity);
        console2.log("  - Has Account:", hasAccount);
        
        console2.log("\n=== Demo Complete ===");
    }
}