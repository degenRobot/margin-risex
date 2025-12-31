// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockUSDC
/// @notice Mock USDC token for testing
/// @dev USDC has 6 decimals like the real token
contract MockUSDC is ERC20, Ownable {
    
    constructor() ERC20("Mock USD Coin", "USDC") {
        // Mint initial supply to deployer for testing
        _mint(msg.sender, 1_000_000 * 10**6); // 1M USDC
    }
    
    /// @notice Returns 6 decimals like real USDC
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    /// @notice Mint tokens to any address (for testing)
    /// @param to Address to mint to
    /// @param amount Amount to mint (with 6 decimals)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /// @notice Faucet function for easy testing
    /// @dev Mints 10,000 USDC to caller
    function faucet() external {
        _mint(msg.sender, 10_000 * 10**6);
    }
}