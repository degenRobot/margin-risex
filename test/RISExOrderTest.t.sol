// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {PortfolioSubAccount} from "../src/PortfolioSubAccount.sol";
import {RISExOrderEncoder, OrderSide} from "../src/RISExOrderEncoder.sol";

contract RISExOrderTest is Test {
    address constant TEST_SUB_ACCOUNT = 0x45525A58b161FFEC104F7F5C2e0a24c831E7E00d;
    address constant PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    address constant DEPLOYER = 0x8E2f075B24Fd64f3E4d0ccab1ade2646AdA9ABAb;
    
    PortfolioSubAccount subAccount;
    RISExOrderEncoder encoder;
    
    // Fork configuration
    string FORK_URL = "https://indexing.testnet.riselabs.xyz";
    
    function setUp() public {
        // Fork from testnet
        vm.createSelectFork(FORK_URL);
        
        subAccount = PortfolioSubAccount(TEST_SUB_ACCOUNT);
        encoder = new RISExOrderEncoder();
    }
    
    function test_OrderPlacementWithExpectedRevert() public {
        console2.log("Testing order placement with expected NotActivated revert");
        
        // Create order
        RISExOrderEncoder.PlaceOrderParams memory params = encoder.createMarketOrder(
            1,              // BTC
            0.001e18,       // 0.001 BTC
            OrderSide.Buy
        );
        bytes memory orderData = encoder.encodePlaceOrder(params);
        
        // Act as the owner
        vm.startPrank(DEPLOYER);
        
        // Method 1: Using vm.expectRevert with specific error
        console2.log("\n1. Testing with vm.expectRevert()");
        
        // Expect the NotActivated custom error
        vm.expectRevert(abi.encodeWithSignature("NotActivated()"));
        subAccount.placeOrder(orderData);
        console2.log("  - Revert caught successfully!");
        
        // Method 2: Using try-catch in a helper
        console2.log("\n2. Testing with try-catch helper");
        (bool success, string memory reason) = _tryPlaceOrder(orderData);
        assertFalse(success);
        console2.log("  - Order failed as expected");
        console2.log("  - Reason:", reason);
        
        vm.stopPrank();
    }
    
    function test_OrderPlacementWithLowGas() public {
        console2.log("Testing order placement with gas limit workaround");
        
        // Create order
        bytes memory orderData = _createTestOrder();
        
        vm.startPrank(DEPLOYER);
        
        // Set a low gas limit to make it fail faster
        uint256 gasLimit = 500000;
        
        // Record gas before
        uint256 gasBefore = gasleft();
        
        // This will revert but with controlled gas usage
        try subAccount.placeOrder{gas: gasLimit}(orderData) {
            console2.log("  - Order succeeded (unexpected)");
        } catch {
            uint256 gasUsed = gasBefore - gasleft();
            console2.log("  - Order reverted with gas used:", gasUsed);
            console2.log("  - This is much less than unlimited gas");
        }
        
        vm.stopPrank();
    }
    
    function test_CheckStateAfterRevert() public {
        console2.log("Testing state after NotActivated revert");
        
        // Get initial state
        (bool success, bytes memory data) = PERPS_MANAGER.staticcall(
            abi.encodeWithSignature("getAccountEquity(address)", TEST_SUB_ACCOUNT)
        );
        
        int256 equityBefore = 0;
        if (success && data.length > 0) {
            equityBefore = abi.decode(data, (int256));
            console2.log("  - Equity before:", uint256(equityBefore) / 1e18, "USDC");
        }
        
        // Try to place order
        bytes memory orderData = _createTestOrder();
        
        vm.startPrank(DEPLOYER);
        
        // We know this will revert
        vm.expectRevert();
        subAccount.placeOrder(orderData);
        
        vm.stopPrank();
        
        // Check state after revert
        (success, data) = PERPS_MANAGER.staticcall(
            abi.encodeWithSignature("getAccountEquity(address)", TEST_SUB_ACCOUNT)
        );
        
        if (success && data.length > 0) {
            int256 equityAfter = abi.decode(data, (int256));
            console2.log("  - Equity after:", uint256(equityAfter) / 1e18, "USDC");
            
            // In some cases, state might change even with revert
            if (equityAfter != equityBefore) {
                console2.log("  - WARNING: State changed despite revert!");
            }
        }
    }
    
    function test_SimulateSuccessfulOrder() public {
        console2.log("Simulating what a successful order would look like");
        
        // Create order data
        bytes memory orderData = _createTestOrder();
        
        // Log what we're trying to do
        console2.log("  - Order data:", vm.toString(orderData));
        console2.log("  - Sub-account:", TEST_SUB_ACCOUNT);
        
        // In production, this would succeed
        // For now, we just document the expected flow
        console2.log("\nExpected flow in production:");
        console2.log("1. Sub-account calls placeOrder()");
        console2.log("2. PerpsManager processes the order");
        console2.log("3. Position is opened");
        console2.log("4. Events are emitted");
        console2.log("5. Account equity reflects the position");
    }
    
    // Helper functions
    function _tryPlaceOrder(bytes memory orderData) internal returns (bool success, string memory reason) {
        try subAccount.placeOrder(orderData) {
            success = true;
            reason = "Success";
        } catch Error(string memory _reason) {
            success = false;
            reason = _reason;
        } catch (bytes memory) {
            success = false;
            reason = "Low-level revert";
        }
    }
    
    function _createTestOrder() internal view returns (bytes memory) {
        RISExOrderEncoder.PlaceOrderParams memory params = encoder.createMarketOrder(
            1,              // BTC
            0.001e18,       // 0.001 BTC
            OrderSide.Buy
        );
        return encoder.encodePlaceOrder(params);
    }
}