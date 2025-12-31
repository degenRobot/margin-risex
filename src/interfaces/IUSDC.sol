// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IUSDC
/// @notice Interface for RISE testnet USDC (TransparentUpgradeableProxy)
interface IUSDC {
    function decimals() external view returns (uint8);
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}