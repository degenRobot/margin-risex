// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MarketParams} from "../../interfaces/IMorpho.sol";

/// @title MarketParamsLib
/// @notice Library for market parameter operations
library MarketParamsLib {
    /// @notice The length of the data used to compute the ID of a market.
    /// @dev The length is 5 * 32 because `MarketParams` has 5 variables of 32 bytes each.
    uint256 internal constant MARKET_PARAMS_BYTES_LENGTH = 5 * 32;

    /// @notice Returns the ID of the market `marketParams`.
    /// @dev The ID is computed as the keccak256 hash of the market parameters.
    function id(MarketParams memory marketParams) internal pure returns (bytes32 marketId) {
        assembly {
            marketId := keccak256(marketParams, MARKET_PARAMS_BYTES_LENGTH)
        }
    }
}