// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {MorphoAdapter} from "../src/adapters/MorphoAdapter.sol";
import {Constants} from "../src/libraries/Constants.sol";
import {IMorpho, MarketParams, Position} from "../src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "../src/libraries/morpho/MarketParamsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title FullFlow
/// @notice Integration test for the complete portfolio margin flow
contract FullFlow is Test {
    using MarketParamsLib for MarketParams;
    PortfolioMarginManager manager;
    PortfolioSubAccount subAccount;
    MorphoAdapter morphoAdapter;
    
    // Test accounts
    address user = makeAddr("user");
    address supplier = Constants.TEST_DEPLOYER; // Has USDC on testnet
    address liquidator = makeAddr("liquidator");
    
    // Tokens
    IERC20 usdc = IERC20(Constants.USDC);
    IERC20 weth = IERC20(Constants.WETH);
    
    // Fork flag
    bool isForked;
    
    function setUp() public {
        // Check if we're in fork mode
        try vm.activeFork() returns (uint256) {
            isForked = true;
            console2.log("Running in fork mode");
        } catch {
            isForked = false;
            console2.log("Running in local mode");
        }
        
        // Deploy contracts
        manager = new PortfolioMarginManager();
        morphoAdapter = MorphoAdapter(address(manager.morphoAdapter()));
        
        // Create sub-account for user
        address subAccountAddr = manager.createSubAccount(user);
        subAccount = PortfolioSubAccount(subAccountAddr);
        
        // Fund accounts
        _fundAccounts();
        
        // Set up Morpho markets with liquidity
        _setupMorphoLiquidity();
    }
    
    function _fundAccounts() private {
        if (isForked) {
            // In fork mode, transfer from funded account
            vm.prank(supplier);
            usdc.transfer(user, 100_000e6); // 100k USDC
            
            // Get WETH for user (deal doesn't work with proxy)
            deal(address(weth), user, 10e18); // 10 WETH
        } else {
            // In local mode, just deal tokens
            deal(address(usdc), user, 100_000e6);
            deal(address(usdc), supplier, 1_000_000e6);
            deal(address(weth), user, 10e18);
        }
    }
    
    function _setupMorphoLiquidity() private {
        // Supplier provides USDC liquidity to Morpho
        MarketParams memory wethMarket = morphoAdapter.getWethMarket();
        
        vm.startPrank(supplier);
        usdc.approve(Constants.MORPHO, 1_000_000e6);
        
        try IMorpho(Constants.MORPHO).supply(
            wethMarket,
            500_000e6, // 500k USDC
            0, // shares
            supplier,
            ""
        ) {
            console2.log("Supplied 500k USDC to WETH market");
        } catch {
            console2.log("Market supply might already exist");
        }
        vm.stopPrank();
    }
    
    function test_FullUserFlow() public {
        console2.log("\n=== Starting Full User Flow ===");
        
        // Step 1: User deposits WETH collateral
        console2.log("\n1. Depositing WETH collateral...");
        MarketParams memory wethMarket = morphoAdapter.getWethMarket();
        
        vm.startPrank(user);
        weth.approve(address(subAccount), 5e18);
        subAccount.supplyToMorpho(wethMarket, 5e18); // 5 WETH
        vm.stopPrank();
        
        // Check position
        Position memory morphoPos = subAccount.getMorphoPosition(wethMarket.id());
        assertEq(morphoPos.collateral, 5e18, "WETH not deposited");
        console2.log("  - Deposited 5 WETH as collateral");
        
        // Step 2: Borrow USDC from Morpho
        console2.log("\n2. Borrowing USDC from Morpho...");
        uint256 maxBorrow = morphoAdapter.calculateMaxBorrow(5e18, wethMarket);
        console2.log("  - Max borrow:", maxBorrow / 1e6, "USDC");
        uint256 borrowAmount = (maxBorrow * 80) / 100; // Borrow 80% of max
        console2.log("  - Borrowing:", borrowAmount / 1e6, "USDC");
        
        vm.prank(user);
        subAccount.borrowFromMorpho(wethMarket, borrowAmount);
        
        uint256 usdcBalance = usdc.balanceOf(address(subAccount));
        assertGt(usdcBalance, 0, "USDC not borrowed");
        console2.log("  - Borrowed", usdcBalance / 1e6, "USDC (stays in sub-account)");
        
        // Step 3: Check portfolio status before RISEx
        console2.log("\n3. Checking portfolio status...");
        (uint256 totalColValue, uint256 totalDebtValue) = manager.getMorphoValues(user);
        console2.log("  - Total Collateral Value:", totalColValue / 1e6, "USDC");
        console2.log("  - Total Debt Value:", totalDebtValue / 1e6, "USDC");
        assertGt(totalColValue, totalDebtValue, "Collateral should exceed debt");
        
        // Step 4: Deposit to RISEx
        console2.log("\n4. Depositing USDC to RISEx...");
        uint256 risexDeposit = 5_000e6; // 5k USDC
        
        vm.prank(user);
        subAccount.depositToRISEx(risexDeposit);
        
        // Note: This will revert with NotActivated but actually succeed
        console2.log("  - Attempted deposit of", risexDeposit / 1e6, "USDC to RISEx");
        console2.log("  - (NotActivated error is normal on testnet)");
        
        // Step 5: Check RISEx status
        console2.log("\n5. Checking RISEx account status...");
        (int256 equity, bool hasAccount) = subAccount.getRISExEquity();
        console2.log("  - RISEx Equity:", equity);
        console2.log("  - Has Account:", hasAccount);
        
        // Step 6: Final portfolio check
        console2.log("\n6. Final portfolio check...");
        (totalColValue, totalDebtValue) = manager.getMorphoValues(user);
        (int256 risexEquity,) = manager.getRISExStatus(user);
        console2.log("  - Morpho Collateral:", totalColValue / 1e6, "USDC");
        console2.log("  - Morpho Debt:", totalDebtValue / 1e6, "USDC");
        console2.log("  - RISEx Equity:", risexEquity);
        
        // Check balances
        (uint256 usdcBal, uint256 wethBal, uint256 wbtcBal) = manager.getSubAccountBalances(user);
        console2.log("  - Sub-account USDC:", usdcBal / 1e6);
        console2.log("  - Sub-account WETH:", wethBal / 1e18);
        console2.log("  - Sub-account WBTC:", wbtcBal / 1e8);
        
        console2.log("\n=== Full User Flow Complete ===");
    }
    
    function test_MultiplePositions() public {
        // Test with both WETH and WBTC positions
        console2.log("\n=== Testing Multiple Positions ===");
        
        // Get WBTC for testing
        deal(address(IERC20(Constants.WBTC)), user, 1e8); // 1 WBTC
        
        // Supply WBTC as collateral
        MarketParams memory wbtcMarket = morphoAdapter.getWbtcMarket();
        
        vm.startPrank(user);
        IERC20(Constants.WBTC).approve(address(subAccount), 1e8);
        subAccount.supplyToMorpho(wbtcMarket, 1e8);
        vm.stopPrank();
        
        // Check positions
        (uint256 wethCol, uint256 wethDebt, uint256 wbtcCol, uint256 wbtcDebt) = manager.getMorphoPositions(user);
        console2.log("\nMorpho Positions:");
        console2.log("  - WETH Collateral:", wethCol / 1e18, "WETH");
        console2.log("  - WETH Market Debt:", wethDebt / 1e6, "USDC");
        console2.log("  - WBTC Collateral:", wbtcCol / 1e8, "WBTC");
        console2.log("  - WBTC Market Debt:", wbtcDebt / 1e6, "USDC");
        
        // Borrow more USDC using WBTC
        uint256 wbtcMaxBorrow = morphoAdapter.calculateMaxBorrow(1e8, wbtcMarket);
        uint256 wbtcBorrowAmount = (wbtcMaxBorrow * 50) / 100; // Borrow 50% of max
        
        vm.prank(user);
        subAccount.borrowFromMorpho(wbtcMarket, wbtcBorrowAmount);
        
        console2.log("\nBorrowed", wbtcBorrowAmount / 1e6, "USDC against WBTC");
        
        // Final check
        (uint256 totalColValue, uint256 totalDebtValue) = manager.getMorphoValues(user);
        console2.log("\nFinal Portfolio:");
        console2.log("  - Total Collateral Value:", totalColValue / 1e6, "USDC");
        console2.log("  - Total Debt Value:", totalDebtValue / 1e6, "USDC");
    }
    
    function test_EmergencyWithdraw() public {
        // Set up position
        test_FullUserFlow();
        
        console2.log("\n\n=== Testing Emergency Withdraw ===");
        
        // User tries to withdraw some collateral
        MarketParams memory wethMarket = morphoAdapter.getWethMarket();
        
        vm.startPrank(user);
        
        // First repay some debt to free up collateral
        uint256 repayAmount = 1_000e6; // Repay 1k USDC
        usdc.approve(address(subAccount), repayAmount);
        subAccount.repayToMorpho(wethMarket, repayAmount);
        
        // Now withdraw some collateral
        uint256 withdrawAmount = 1e18; // 1 WETH
        subAccount.withdrawFromMorpho(wethMarket, withdrawAmount, user);
        
        vm.stopPrank();
        
        console2.log("Emergency withdrawal complete");
        console2.log("  - Repaid:", repayAmount / 1e6, "USDC");
        console2.log("  - Withdrew:", withdrawAmount / 1e18, "WETH");
        
        // Check final state
        (uint256 finalColValue, uint256 finalDebtValue) = manager.getMorphoValues(user);
        console2.log("\nFinal state:");
        console2.log("  - Collateral Value:", finalColValue / 1e6, "USDC");
        console2.log("  - Debt Value:", finalDebtValue / 1e6, "USDC");
        assertGt(finalColValue, finalDebtValue, "Should maintain healthy position");
    }
}