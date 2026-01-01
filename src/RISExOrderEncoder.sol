// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title Order Types for RISEx
/// @notice Enums and structs for order management
/// @dev These types mirror the RISEx protocol's order system

// Order side - Buy or Sell
enum OrderSide {
    Buy,
    Sell
}

// Self-Trade Prevention mode
enum STPMode {
    None,
    Expire,
    Cancel,
    Both
}

// Order types
enum OrderType {
    Market,
    Limit
}

// Time in force conditions
enum TimeInForce {
    GoodTilCancel,
    ImmediateOrCancel,
    FillOrKill
}

/// @title RISExOrderEncoder
/// @notice Library for encoding order data in RISEx binary format
/// @dev Encodes order parameters into the compact binary format expected by RISEx contracts
contract RISExOrderEncoder {
    // Constants for place order data byte layout
    uint256 private constant PLACE_ORDER_DATA_LENGTH = 47;
    
    // Bit masks for packed flags byte
    uint8 private constant SIDE_MASK = 0x01; // bit 0: side (0 = Buy, 1 = Sell)
    uint8 private constant POST_ONLY_MASK = 0x02; // bit 1: postOnly
    uint8 private constant REDUCE_ONLY_MASK = 0x04; // bit 2: reduceOnly
    uint8 private constant STP_MODE_SHIFT = 3; // bits 3-4: stpMode

    /// @notice Parameters for placing an order
    struct PlaceOrderParams {
        uint256 marketId;
        uint128 size;
        uint128 price;
        OrderSide side;
        STPMode stpMode;
        OrderType orderType;
        bool postOnly;
        bool reduceOnly;
        TimeInForce timeInForce;
        uint32 expiry;
    }

    /// @notice Encode place order parameters into binary format
    /// @dev Binary layout (47 bytes total):
    ///   bytes[0:8]    - marketId (uint64, 8 bytes)
    ///   bytes[8:24]   - size (uint128, 16 bytes)
    ///   bytes[24:40]  - price (uint128, 16 bytes)
    ///   byte[40]      - flags (uint8, 1 byte packed):
    ///                     bit 0: side (0 = Buy, 1 = Sell)
    ///                     bit 1: postOnly
    ///                     bit 2: reduceOnly
    ///                     bits 3-4: stpMode (2 bits)
    ///                     bits 5-7: unused
    ///   bytes[41]     - orderType (uint8, 1 byte)
    ///   bytes[42]     - timeInForce (uint8, 1 byte)
    ///   bytes[43:47]  - expiry (uint32, 4 bytes)
    /// @param params Order parameters to encode
    /// @return encodedData The encoded order data
    function encodePlaceOrder(PlaceOrderParams memory params) public pure returns (bytes memory) {
        // Pack flags into a single uint8 byte
        uint8 flags = 0;
        if (params.side == OrderSide.Sell) flags |= SIDE_MASK; // bit 0
        if (params.postOnly) flags |= POST_ONLY_MASK; // bit 1
        if (params.reduceOnly) flags |= REDUCE_ONLY_MASK; // bit 2
        flags |= uint8(params.stpMode) << STP_MODE_SHIFT; // bits 3-4

        // Create 47-byte encoded data
        bytes memory encodedData = new bytes(PLACE_ORDER_DATA_LENGTH);
        
        // Encode marketId (uint64)
        uint256 marketId = params.marketId;
        assembly {
            mstore8(add(encodedData, 32), shr(56, marketId))
            mstore8(add(encodedData, 33), shr(48, marketId))
            mstore8(add(encodedData, 34), shr(40, marketId))
            mstore8(add(encodedData, 35), shr(32, marketId))
            mstore8(add(encodedData, 36), shr(24, marketId))
            mstore8(add(encodedData, 37), shr(16, marketId))
            mstore8(add(encodedData, 38), shr(8, marketId))
            mstore8(add(encodedData, 39), marketId)
        }
        
        // Encode size (uint128)
        uint128 size = params.size;
        assembly {
            let sizeOffset := add(encodedData, 40) // 32 + 8
            mstore(sizeOffset, shl(128, size))
        }
        
        // Encode price (uint128)
        uint128 price = params.price;
        assembly {
            let priceOffset := add(encodedData, 56) // 32 + 24
            mstore(priceOffset, shl(128, price))
        }
        
        // Encode flags, orderType, timeInForce
        encodedData[40] = bytes1(flags);
        encodedData[41] = bytes1(uint8(params.orderType));
        encodedData[42] = bytes1(uint8(params.timeInForce));
        
        // Encode expiry (uint32)
        uint32 expiry = params.expiry;
        assembly {
            let expiryOffset := add(encodedData, 75) // 32 + 43
            mstore8(expiryOffset, shr(24, expiry))
            mstore8(add(expiryOffset, 1), shr(16, expiry))
            mstore8(add(expiryOffset, 2), shr(8, expiry))
            mstore8(add(expiryOffset, 3), expiry)
        }
        
        return encodedData;
    }

    /// @notice Encode cancel order parameters into binary format
    /// @dev Binary layout (32 bytes total):
    ///   bytes[0:8]    - marketId (uint64, 8 bytes)
    ///   bytes[8:32]   - orderId (uint192, 24 bytes)
    /// @param marketId Market ID
    /// @param orderId Order ID to cancel
    /// @return encodedData The encoded cancel order data as bytes32
    function encodeCancelOrder(uint64 marketId, uint192 orderId) public pure returns (bytes32) {
        // Combine marketId (8 bytes) and orderId (24 bytes) into bytes32
        return bytes32(uint256(marketId) << 192) | bytes32(uint256(orderId));
    }

    /// @notice Create a market order with minimal parameters
    /// @param marketId Market ID (1 = BTC, 2 = ETH)
    /// @param size Position size (in base asset units with 18 decimals)
    /// @param side Order side (Buy/Sell)
    /// @return params Formatted order parameters
    function createMarketOrder(
        uint256 marketId,
        uint128 size,
        OrderSide side
    ) external pure returns (PlaceOrderParams memory params) {
        params = PlaceOrderParams({
            marketId: marketId,
            size: size,
            price: 0, // Market orders don't need price
            side: side,
            stpMode: STPMode.None,
            orderType: OrderType.Market,
            postOnly: false,
            reduceOnly: false,
            timeInForce: TimeInForce.ImmediateOrCancel,
            expiry: 0 // Not used for ImmediateOrCancel orders
        });
    }

    /// @notice Create a limit order with full parameters
    /// @param marketId Market ID (1 = BTC, 2 = ETH)
    /// @param size Position size (in base asset units with 18 decimals)
    /// @param price Limit price (in quote asset units with 18 decimals)
    /// @param side Order side (Buy/Sell)
    /// @param postOnly Whether order should only add liquidity
    /// @return params Formatted order parameters
    function createLimitOrder(
        uint256 marketId,
        uint128 size,
        uint128 price,
        OrderSide side,
        bool postOnly
    ) external view returns (PlaceOrderParams memory params) {
        params = PlaceOrderParams({
            marketId: marketId,
            size: size,
            price: price,
            side: side,
            stpMode: STPMode.None,
            orderType: OrderType.Limit,
            postOnly: postOnly,
            reduceOnly: false,
            timeInForce: TimeInForce.GoodTilCancel,
            expiry: uint32(block.timestamp + 7 days) // Default 7 day expiry
        });
    }

    /// @notice Create a reduce-only order to close a position
    /// @param marketId Market ID
    /// @param size Position size to close
    /// @param price Limit price (0 for market order)
    /// @param side Order side (opposite of position side)
    /// @return params Formatted order parameters
    function createReduceOnlyOrder(
        uint256 marketId,
        uint128 size,
        uint128 price,
        OrderSide side
    ) external pure returns (PlaceOrderParams memory params) {
        bool isMarket = price == 0;
        
        params = PlaceOrderParams({
            marketId: marketId,
            size: size,
            price: price,
            side: side,
            stpMode: STPMode.None,
            orderType: isMarket ? OrderType.Market : OrderType.Limit,
            postOnly: false,
            reduceOnly: true,
            timeInForce: TimeInForce.ImmediateOrCancel,
            expiry: 0
        });
    }
}