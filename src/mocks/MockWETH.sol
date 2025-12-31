// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockWETH
/// @notice Mock WETH token for testing - 18 decimals
contract MockWETH is ERC20, Ownable {
    
    constructor() ERC20("Wrapped Ether", "WETH") {}
    
    /// @notice Mint tokens to an address
    /// @param to Address to mint to
    /// @param amount Amount to mint (18 decimals)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    /// @notice Burn tokens from msg.sender
    /// @param amount Amount to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    /// @notice Deposit ETH and mint WETH
    receive() external payable {
        _mint(msg.sender, msg.value);
    }
    
    /// @notice Withdraw WETH and receive ETH
    /// @param amount Amount of WETH to withdraw
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}