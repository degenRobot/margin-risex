// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockWBTC
/// @notice Mock WBTC token for testing - 8 decimals (like real WBTC)
contract MockWBTC is ERC20, Ownable {
    
    constructor() ERC20("Wrapped Bitcoin", "WBTC") {}
    
    /// @notice Returns 8 decimals like real WBTC
    function decimals() public pure override returns (uint8) {
        return 8;
    }
    
    /// @notice Mint tokens to an address
    /// @param to Address to mint to
    /// @param amount Amount to mint (8 decimals)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /// @notice Burn tokens from msg.sender
    /// @param amount Amount to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}