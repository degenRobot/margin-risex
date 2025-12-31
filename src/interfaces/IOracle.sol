// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IOracle
/// @notice Interface for Morpho Blue oracle
interface IOracle {
    /// @notice Get the price of the collateral token in terms of the loan token
    /// @return The price scaled by 1e36
    function price() external view returns (uint256);
}