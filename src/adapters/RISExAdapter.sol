// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRISExPerpsManager, IWhitelist} from "../interfaces/IRISExPerpsManager.sol";
import {RISExOrderEncoder} from "../libraries/RISExOrderEncoder.sol";

/// @title RISExAdapter
/// @notice Adapter contract to simplify RISEx integration
/// @dev Handles order encoding, whitelist checks, and common operations
contract RISExAdapter {
    using RISExOrderEncoder for *;
    
    // RISEx addresses on RISE testnet
    address public constant RISEX_PERPS = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    address public constant RISEX_WHITELIST = 0x5b2Fcc7C1efC8f8D9968a5de2F51063984db41E5;
    address public constant RISEX_AUTH = 0x8d8708f9D87ef522c1f99DD579BF6A051e34C28E;
    
    // Error definitions
    error NotWhitelisted(address account);
    error InvalidMarketId(uint256 marketId);
    error InvalidOrderSize(uint128 size);
    
    /// @notice Check if an account is whitelisted
    /// @param account The account to check
    /// @return Whether the account is whitelisted
    function isWhitelisted(address account) public view returns (bool) {
        return IWhitelist(RISEX_WHITELIST).isWhitelisted(account);
    }
    
    /// @notice Request whitelist access for an account
    /// @param account The account to request access for
    function requestWhitelistAccess(address account) external {
        IWhitelist(RISEX_WHITELIST).requestWhitelistAccess(account);
    }
    
    /// @notice Create a market order for BTC
    /// @param size Position size in BTC (18 decimals)
    /// @param isBuy True for long, false for short
    /// @return Encoded order data
    function createBTCMarketOrder(
        uint128 size,
        bool isBuy
    ) external pure returns (bytes memory) {
        return RISExOrderEncoder.encodeMarketOrder(
            RISExOrderEncoder.MARKET_BTC,
            size,
            isBuy ? RISExOrderEncoder.OrderSide.Buy : RISExOrderEncoder.OrderSide.Sell
        );
    }
    
    /// @notice Create a market order for ETH
    /// @param size Position size in ETH (18 decimals)
    /// @param isBuy True for long, false for short
    /// @return Encoded order data
    function createETHMarketOrder(
        uint128 size,
        bool isBuy
    ) external pure returns (bytes memory) {
        return RISExOrderEncoder.encodeMarketOrder(
            RISExOrderEncoder.MARKET_ETH,
            size,
            isBuy ? RISExOrderEncoder.OrderSide.Buy : RISExOrderEncoder.OrderSide.Sell
        );
    }
    
    /// @notice Create a limit order for BTC
    /// @param size Position size in BTC (18 decimals)
    /// @param price Limit price in USDC (6 decimals)
    /// @param isBuy True for long, false for short
    /// @param postOnly Whether to post only
    /// @return Encoded order data
    function createBTCLimitOrder(
        uint128 size,
        uint128 price,
        bool isBuy,
        bool postOnly
    ) external view returns (bytes memory) {
        return RISExOrderEncoder.encodeLimitOrder(
            RISExOrderEncoder.MARKET_BTC,
            size,
            price,
            isBuy ? RISExOrderEncoder.OrderSide.Buy : RISExOrderEncoder.OrderSide.Sell,
            postOnly
        );
    }
    
    /// @notice Create a limit order for ETH
    /// @param size Position size in ETH (18 decimals)
    /// @param price Limit price in USDC (6 decimals)
    /// @param isBuy True for long, false for short
    /// @param postOnly Whether to post only
    /// @return Encoded order data
    function createETHLimitOrder(
        uint128 size,
        uint128 price,
        bool isBuy,
        bool postOnly
    ) external view returns (bytes memory) {
        return RISExOrderEncoder.encodeLimitOrder(
            RISExOrderEncoder.MARKET_ETH,
            size,
            price,
            isBuy ? RISExOrderEncoder.OrderSide.Buy : RISExOrderEncoder.OrderSide.Sell,
            postOnly
        );
    }
    
    /// @notice Encode cancel order data
    /// @param marketId The market ID
    /// @param orderId The order ID to cancel
    /// @return Encoded cancel data
    function encodeCancelOrder(
        uint64 marketId,
        uint192 orderId
    ) external pure returns (bytes32) {
        return RISExOrderEncoder.encodeCancelOrder(marketId, orderId);
    }
    
    /// @notice Get comprehensive account info from RISEx
    /// @param account The account to check
    /// @return equity Total account equity
    /// @return crossMarginBalance Cross margin balance
    /// @return usdcBalance USDC balance
    /// @return withdrawableUSDC Withdrawable USDC amount
    function getAccountInfo(address account) external view returns (
        int256 equity,
        int256 crossMarginBalance,
        int256 usdcBalance,
        uint256 withdrawableUSDC
    ) {
        IRISExPerpsManager risex = IRISExPerpsManager(RISEX_PERPS);
        
        equity = risex.getAccountEquity(account);
        crossMarginBalance = risex.getCrossMarginBalance(account);
        usdcBalance = risex.getBalance(account, 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58); // USDC
        withdrawableUSDC = risex.getWithdrawableAmount(account, 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58);
    }
    
    /// @notice Check if an account needs whitelisting before trading
    /// @param account The account to check
    /// @dev Reverts if not whitelisted
    modifier requiresWhitelist(address account) {
        if (!isWhitelisted(account)) {
            revert NotWhitelisted(account);
        }
        _;
    }
}