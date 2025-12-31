// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IIrm} from "morpho-blue/interfaces/IIrm.sol";
import {MarketParams, Market} from "morpho-blue/interfaces/IMorpho.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockIRM
/// @notice Mock Interest Rate Model for Morpho Blue with constant rate
/// @dev Returns a fixed borrow rate per second, scaled by 1e18 (WAD)
contract MockIRM is IIrm, Ownable {
    
    uint256 private constant WAD = 1e18;
    uint256 private _borrowRatePerSecond;
    
    /// @notice Emitted when rate is updated
    event RateUpdated(uint256 newRate);
    
    /// @param initialRatePerYear Annual interest rate scaled by 1e18 (e.g., 0.05e18 = 5% APR)
    constructor(uint256 initialRatePerYear) {
        _setBorrowRateFromAPR(initialRatePerYear);
    }
    
    /// @notice Returns the borrow rate per second
    /// @dev Rate is scaled by WAD (1e18) as per Morpho's IIrm interface
    function borrowRate(MarketParams memory, Market memory) external override returns (uint256) {
        return _borrowRatePerSecond;
    }
    
    /// @notice Returns the borrow rate per second (view function)
    /// @dev Rate is scaled by WAD (1e18) as per Morpho's IIrm interface
    function borrowRateView(MarketParams memory, Market memory) external view override returns (uint256) {
        return _borrowRatePerSecond;
    }
    
    /// @notice Set a new borrow rate from annual percentage rate
    /// @param ratePerYear Annual rate scaled by 1e18 (e.g., 0.05e18 = 5% APR)
    function setRateFromAPR(uint256 ratePerYear) external onlyOwner {
        _setBorrowRateFromAPR(ratePerYear);
        emit RateUpdated(_borrowRatePerSecond);
    }
    
    /// @notice Set the borrow rate directly (per second)
    /// @param ratePerSecond Rate per second scaled by 1e18
    function setRatePerSecond(uint256 ratePerSecond) external onlyOwner {
        _borrowRatePerSecond = ratePerSecond;
        emit RateUpdated(ratePerSecond);
    }
    
    /// @notice Get current APR for display purposes
    /// @return Annual percentage rate scaled by 1e18
    function getAPR() external view returns (uint256) {
        return _borrowRatePerSecond * 365 days;
    }
    
    /// @dev Internal function to set rate from APR
    function _setBorrowRateFromAPR(uint256 ratePerYear) private {
        // Convert annual rate to per-second rate
        // ratePerSecond = ratePerYear / secondsPerYear
        _borrowRatePerSecond = ratePerYear / 365 days;
    }
}