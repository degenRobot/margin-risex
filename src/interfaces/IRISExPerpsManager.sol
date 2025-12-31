// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IRISExPerpsManager
/// @notice Interface for RISEx Perpetual Manager
/// @dev Updated to match actual RISEx deployment on RISE testnet
interface IRISExPerpsManager {
    
    /// @notice Deposit collateral into RISEx for an account
    /// @param to The account to deposit for
    /// @param token The collateral token address
    /// @param amount The amount to deposit
    function deposit(address to, address token, uint256 amount) external;
    
    /// @notice Withdraw collateral from RISEx
    /// @param to The account to receive tokens
    /// @param token The collateral token address
    /// @param amount The amount to withdraw
    function withdraw(address to, address token, uint256 amount) external;
    
    /// @notice Get balance for a specific token
    /// @param account The account to check
    /// @param token The collateral token address
    /// @return The balance (can be negative)
    function getBalance(address account, address token) external view returns (int256);
    
    /// @notice Get withdrawable amount for a specific token
    /// @param account The account to check
    /// @param token The collateral token address
    /// @return The amount that can be withdrawn
    function getWithdrawableAmount(address account, address token) external view returns (uint256);
    
    /// @notice Get total account equity including unrealized PnL
    /// @param account The account to check
    /// @return Account equity (can be negative if in loss)
    function getAccountEquity(address account) external view returns (int256);
    
    /// @notice Get cross margin balance
    /// @param account The account to check
    /// @return Cross margin balance
    function getCrossMarginBalance(address account) external view returns (int256);
    
    /// @notice Place a trading order
    /// @param placeOrderData Encoded order data (47 bytes)
    /// @return orderId The ID of the placed order
    function placeOrder(bytes calldata placeOrderData) external returns (uint256 orderId);
    
    /// @notice Cancel an existing order
    /// @param cancelOrderData Encoded cancel order data (bytes32: marketId + orderId)
    function cancelOrder(bytes32 cancelOrderData) external;
    
    /// @notice Place order with permit for session key support
    /// @param placeOrderData Encoded order data
    /// @param account The account placing the order
    /// @param signer The signer (session key)
    /// @param deadline Permit deadline
    /// @param signature Permit signature
    /// @param nonce Permit nonce
    /// @return orderId The ID of the placed order
    function placeOrderWithPermit(
        bytes calldata placeOrderData,
        address account,
        address signer,
        uint256 deadline,
        bytes calldata signature,
        uint256 nonce
    ) external returns (uint256 orderId);
    
    /// @notice Cancel order with permit for session key support
    /// @param cancelOrderData Encoded cancel order data
    /// @param account The account canceling the order
    /// @param signer The signer (session key)
    /// @param deadline Permit deadline
    /// @param signature Permit signature
    /// @param nonce Permit nonce
    function cancelOrderWithPermit(
        bytes32 cancelOrderData,
        address account,
        address signer,
        uint256 deadline,
        bytes calldata signature,
        uint256 nonce
    ) external;
    
    // Recommended addition for clean liquidations (would need RISEx to implement)
    // function forceCloseAllPositions(address account) external returns (int256 realizedPnL);
}

/// @notice Whitelist interface for RISEx
interface IWhitelist {
    function isWhitelisted(address account) external view returns (bool);
    function requestWhitelistAccess(address account) external;
}

/// @notice RISEx Deposit contract interface (alternative deposit method)
interface IDeposit {
    function deposit(address to, uint256 amount) external;
}