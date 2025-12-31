// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IRISExPerpsManager
/// @notice Minimal interface for RISEx Perpetual Manager
/// @dev Only includes functions needed for portfolio margin integration
interface IRISExPerpsManager {
    
    /// @notice Deposit collateral into RISEx for an account
    /// @param account The account to deposit for
    /// @param token The collateral token address
    /// @param amount The amount to deposit
    function deposit(address account, address token, uint256 amount) external;
    
    /// @notice Withdraw collateral from RISEx
    /// @param account The account to withdraw from
    /// @param token The collateral token address
    /// @param amount The amount to withdraw
    function withdraw(address account, address token, uint256 amount) external;
    
    /// @notice Get withdrawable amount for a specific token
    /// @param account The account to check
    /// @param token The collateral token address
    /// @return The amount that can be withdrawn
    function getWithdrawableAmount(address account, address token) external view returns (uint256);
    
    /// @notice Get total account equity including unrealized PnL
    /// @param account The account to check
    /// @return Account equity (can be negative if in loss)
    function getAccountEquity(address account) external view returns (int256);
    
    /// @notice Place a trading order
    /// @param placeOrderData Encoded order data
    /// @return orderId The ID of the placed order
    function placeOrder(bytes calldata placeOrderData) external returns (uint256 orderId);
    
    /// @notice Cancel an existing order
    /// @param cancelOrderData Encoded cancel order data
    function cancelOrder(bytes32 cancelOrderData) external;
    
    // Optional: Add session key support
    // function placeOrderWithPermit(bytes calldata placeOrderData, bytes calldata permit) external returns (uint256);
    // function cancelOrderWithPermit(bytes32 cancelOrderData, bytes calldata permit) external;
    
    // Recommended addition for clean liquidations (would need RISEx to implement)
    // function forceCloseAllPositions(address account) external returns (int256 realizedPnL);
}