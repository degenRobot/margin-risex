// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracle} from "morpho-blue/interfaces/IOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockOracle
/// @notice Mock oracle for Morpho Blue markets with admin-settable prices
/// @dev Returns price of collateral quoted in loan token, scaled by 1e36
contract MockOracle is IOracle, Ownable {
    
    uint256 private _price;
    
    /// @notice Emitted when price is updated
    event PriceUpdated(uint256 newPrice);
    
    constructor(uint256 initialPrice) {
        _price = initialPrice;
    }
    
    /// @notice Returns the price of collateral in loan token terms
    /// @dev Price is scaled by 1e36 as per Morpho's IOracle interface
    /// @return Current price
    function price() external view override returns (uint256) {
        return _price;
    }
    
    /// @notice Set a new price
    /// @param newPrice New price scaled by 1e36
    function setPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be positive");
        _price = newPrice;
        emit PriceUpdated(newPrice);
    }
    
    /// @notice Helper to calculate price with decimals adjustment
    /// @param collateralPrice Price of 1 unit of collateral in USD
    /// @param loanPrice Price of 1 unit of loan token in USD  
    /// @param collateralDecimals Decimals of collateral token
    /// @param loanDecimals Decimals of loan token
    /// @return Price scaled for Morpho (1e36)
    function calculateMorphoPrice(
        uint256 collateralPrice,
        uint256 loanPrice,
        uint8 collateralDecimals,
        uint8 loanDecimals
    ) external pure returns (uint256) {
        // Price = (collateralPrice / loanPrice) * 10^(36 + loanDecimals - collateralDecimals)
        return (collateralPrice * 10**(36 + loanDecimals - collateralDecimals)) / loanPrice;
    }
}