// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BasicSubAccount
/// @notice Simple sub-account for holding assets and attempting RISEx deposits
/// @dev No proxy pattern, just a straightforward contract
contract BasicSubAccount is Ownable {
    using SafeERC20 for IERC20;
    
    // RISEx contracts
    // NOTE: We skip using DEPOSIT_CONTRACT (0x5BC20A936EfEE0d758A3c168d2f017c83805B986) as it also mints USDC
    // Instead, we deposit directly to PERPS_MANAGER which works on testnet
    address public constant PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    
    // Token addresses
    address public constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    
    // Events
    event Deposited(address indexed token, uint256 amount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event RISExDepositAttempted(uint256 amount, bool success);
    
    constructor(address _owner) Ownable() {
        _transferOwnership(_owner);
    }
    
    /// @notice Deposit tokens to this sub-account
    /// @param token Token address
    /// @param amount Amount to deposit
    function deposit(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(token, amount);
    }
    
    /// @notice Withdraw tokens from this sub-account
    /// @param token Token address
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawn(token, to, amount);
    }
    
    /// @notice Deposit USDC to RISEx via direct PerpsManager deposit
    /// @param amount Amount of USDC to deposit (6 decimals)
    /// @return success Whether the deposit succeeded
    /// @dev We deposit directly to PerpsManager instead of using Deposit contract
    function depositToRISEx(uint256 amount) external onlyOwner returns (bool success) {
        // Check balance
        require(IERC20(USDC).balanceOf(address(this)) >= amount, "Insufficient USDC");
        
        // Approve PerpsManager directly
        IERC20(USDC).approve(PERPS_MANAGER, amount);
        
        // Deposit directly to PerpsManager (no scaling needed - use 6 decimals)
        try IPerpsManager(PERPS_MANAGER).deposit(address(this), USDC, amount) {
            success = true;
            emit RISExDepositAttempted(amount, true);
        } catch {
            success = false;
            emit RISExDepositAttempted(amount, false);
            // Reset approval
            IERC20(USDC).approve(PERPS_MANAGER, 0);
        }
    }
    
    /// @notice Get balance of any token
    /// @param token Token address
    /// @return Balance of the token
    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    /// @notice Check RISEx account equity
    /// @return equity Account equity in RISEx
    /// @return hasAccount Whether the account exists in RISEx
    function checkRISExStatus() external view returns (int256 equity, bool hasAccount) {
        try IPerpsManager(PERPS_MANAGER).getAccountEquity(address(this)) returns (int256 _equity) {
            return (_equity, true);
        } catch {
            return (0, false);
        }
    }
}

/// @notice Minimal interfaces for RISEx interaction
interface IPerpsManager {
    function deposit(address to, address token, uint256 amount) external;
    function getAccountEquity(address account) external view returns (int256);
}