// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IDeposit
/// @notice Interface for RISEx Deposit Contract
/// @dev This contract acts as an intermediary for deposits to PerpsManager
interface IDeposit {
    /// @notice Deposit tokens to an account in PerpsManager
    /// @dev This contract will mint USDC internally and deposit to PerpsManager
    /// @param to The account to deposit tokens to
    /// @param amount The amount of tokens to deposit (in 18 decimals)
    function deposit(address to, uint256 amount) external;
}