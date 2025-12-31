// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title RISExOrderEncoder
/// @notice Library for encoding RISEx order data
/// @dev Handles encoding of orders for placeOrder and cancelOrder functions
library RISExOrderEncoder {
    // Order side enum matching RISEx
    enum OrderSide {
        Buy,
        Sell
    }
    
    // Order type enum matching RISEx
    enum OrderType {
        Market,
        Limit
    }
    
    // STP mode enum matching RISEx
    enum STPMode {
        ExpireMaker,
        ExpireTaker,
        ExpireBoth,
        None
    }
    
    // Time in force enum matching RISEx
    enum TimeInForce {
        GoodTillCancelled,
        GoodTillTime,
        FillOrKill,
        ImmediateOrCancel
    }
    
    // Market IDs on RISE testnet
    uint256 constant MARKET_BTC = 1;
    uint256 constant MARKET_ETH = 2;
    
    // Bit masks for packed flags byte
    uint8 private constant SIDE_MASK = 0x01;         // bit 0: side (0 = Buy, 1 = Sell)
    uint8 private constant POST_ONLY_MASK = 0x02;    // bit 1: postOnly
    uint8 private constant REDUCE_ONLY_MASK = 0x04;  // bit 2: reduceOnly
    uint8 private constant STP_MODE_SHIFT = 3;       // bits 3-4: stpMode
    
    /// @notice Encode a market order
    /// @param marketId The market ID (1 for BTC, 2 for ETH)
    /// @param size The position size (with proper decimals)
    /// @param side Buy or Sell
    /// @return Encoded order data (47 bytes)
    function encodeMarketOrder(
        uint256 marketId,
        uint128 size,
        OrderSide side
    ) internal pure returns (bytes memory) {
        return encodePlaceOrder(
            marketId,
            size,
            0, // price not needed for market orders
            side,
            STPMode.None,
            OrderType.Market,
            false, // postOnly
            false, // reduceOnly
            TimeInForce.ImmediateOrCancel,
            0 // expiry not used for IOC
        );
    }
    
    /// @notice Encode a limit order
    /// @param marketId The market ID (1 for BTC, 2 for ETH)
    /// @param size The position size (with proper decimals)
    /// @param price The limit price
    /// @param side Buy or Sell
    /// @param postOnly Whether to post only
    /// @return Encoded order data (47 bytes)
    function encodeLimitOrder(
        uint256 marketId,
        uint128 size,
        uint128 price,
        OrderSide side,
        bool postOnly
    ) internal view returns (bytes memory) {
        return encodePlaceOrder(
            marketId,
            size,
            price,
            side,
            STPMode.None,
            OrderType.Limit,
            postOnly,
            false, // reduceOnly
            TimeInForce.GoodTillCancelled,
            uint32(block.timestamp + 86400) // 24 hours
        );
    }
    
    /// @notice Encode place order data
    /// @dev Binary layout (47 bytes total):
    ///   bytes[0:8]    - marketId (uint64, 8 bytes)
    ///   bytes[8:24]   - size (uint128, 16 bytes)
    ///   bytes[24:40]  - price (uint128, 16 bytes)
    ///   byte[40]      - flags (uint8, 1 byte packed)
    ///   bytes[41]     - orderType (uint8, 1 byte)
    ///   bytes[42]     - timeInForce (uint8, 1 byte)
    ///   bytes[43:47]  - expiry (uint32, 4 bytes)
    function encodePlaceOrder(
        uint256 marketId,
        uint128 size,
        uint128 price,
        OrderSide side,
        STPMode stpMode,
        OrderType orderType,
        bool postOnly,
        bool reduceOnly,
        TimeInForce timeInForce,
        uint32 expiry
    ) internal pure returns (bytes memory) {
        // Pack flags into a single uint8
        uint8 flags = 0;
        if (side == OrderSide.Sell) flags |= SIDE_MASK;
        if (postOnly) flags |= POST_ONLY_MASK;
        if (reduceOnly) flags |= REDUCE_ONLY_MASK;
        flags |= uint8(stpMode) << STP_MODE_SHIFT;
        
        // Create 47-byte encoded data
        bytes memory data = new bytes(47);
        
        // Encode marketId (uint64, 8 bytes)
        assembly {
            mstore8(add(data, 32), shr(56, marketId))
            mstore8(add(data, 33), shr(48, marketId))
            mstore8(add(data, 34), shr(40, marketId))
            mstore8(add(data, 35), shr(32, marketId))
            mstore8(add(data, 36), shr(24, marketId))
            mstore8(add(data, 37), shr(16, marketId))
            mstore8(add(data, 38), shr(8, marketId))
            mstore8(add(data, 39), marketId)
        }
        
        // Encode size (uint128, 16 bytes)
        assembly {
            let sizeOffset := add(data, 40) // 32 + 8
            mstore(sizeOffset, shl(128, size))
        }
        
        // Encode price (uint128, 16 bytes)
        assembly {
            let priceOffset := add(data, 56) // 32 + 24
            mstore(priceOffset, shl(128, price))
        }
        
        // Encode flags, orderType, timeInForce
        data[40] = bytes1(flags);
        data[41] = bytes1(uint8(orderType));
        data[42] = bytes1(uint8(timeInForce));
        
        // Encode expiry (uint32, 4 bytes)
        assembly {
            let expiryOffset := add(data, 75) // 32 + 43
            mstore8(expiryOffset, shr(24, expiry))
            mstore8(add(expiryOffset, 1), shr(16, expiry))
            mstore8(add(expiryOffset, 2), shr(8, expiry))
            mstore8(add(expiryOffset, 3), expiry)
        }
        
        return data;
    }
    
    /// @notice Encode cancel order data
    /// @param marketId The market ID (max uint64)
    /// @param orderId The order ID (max uint192)
    /// @return Encoded cancel data (bytes32)
    function encodeCancelOrder(
        uint64 marketId,
        uint192 orderId
    ) internal pure returns (bytes32) {
        // Combine marketId (8 bytes) and orderId (24 bytes) into bytes32
        return bytes32(uint256(marketId) << 192) | bytes32(uint256(orderId));
    }
}