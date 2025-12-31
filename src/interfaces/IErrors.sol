// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IErrors
/// @notice Common error definitions for the Portfolio Margin System
interface IErrors {
    // ============ General Errors ============
    
    /// @notice Thrown when an invalid address (e.g., address(0)) is provided
    error InvalidAddress();
    
    /// @notice Thrown when an invalid amount (e.g., 0) is provided
    error InvalidAmount();
    
    /// @notice Thrown when caller is not authorized
    error Unauthorized();
    
    /// @notice Thrown when contract is paused
    error ContractPaused();
    
    /// @notice Thrown when trying to initialize an already initialized contract
    error AlreadyInitialized();
    
    // ============ Portfolio Margin Manager Errors ============
    
    /// @notice Thrown when user already has a sub-account
    error SubAccountExists();
    
    /// @notice Thrown when user doesn't have a sub-account
    error NoSubAccount();
    
    /// @notice Thrown when market is not supported
    error UnsupportedMarket(bytes32 marketId);
    
    /// @notice Thrown when collateral factor is invalid
    error InvalidCollateralFactor();
    
    /// @notice Thrown when portfolio is healthy and cannot be liquidated
    error PortfolioHealthy();
    
    // ============ Portfolio SubAccount Errors ============
    
    /// @notice Thrown when only user can call
    error OnlyUser();
    
    /// @notice Thrown when only manager can call
    error OnlyManager();
    
    /// @notice Thrown when only user or manager can call
    error OnlyUserOrManager();
    
    /// @notice Thrown when health check fails
    error UnhealthyPosition();
    
    // ============ RISEx Integration Errors ============
    
    /// @notice Thrown when account is not whitelisted on RISEx
    error NotWhitelisted(address account);
    
    /// @notice Thrown when order size is invalid
    error InvalidOrderSize();
    
    /// @notice Thrown when market ID is invalid
    error InvalidMarketId(uint256 marketId);
    
    /// @notice Thrown when order encoding fails
    error InvalidOrderData();
    
    // ============ Morpho Integration Errors ============
    
    /// @notice Thrown when trying to withdraw more than available
    error InsufficientCollateral();
    
    /// @notice Thrown when trying to borrow more than allowed
    error BorrowCapExceeded();
    
    /// @notice Thrown when repay amount exceeds debt
    error ExcessiveRepayment();
}