// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMorpho, MarketParams, Position, Market} from "../interfaces/IMorpho.sol";
import {MarketParamsLib} from "../libraries/morpho/MarketParamsLib.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {Constants} from "../libraries/Constants.sol";

/// @title MorphoAdapter
/// @notice Adapter contract to simplify Morpho Blue operations
/// @dev Provides helper functions for common market operations
contract MorphoAdapter {
    using MarketParamsLib for MarketParams;
    
    IMorpho public constant MORPHO = IMorpho(Constants.MORPHO);
    
    // Pre-configured market parameters
    // Note: Cannot use constant for structs in Solidity
    function getWethMarket() public pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: Constants.USDC,
            collateralToken: Constants.WETH,
            oracle: Constants.WETH_ORACLE,
            irm: Constants.IRM,
            lltv: Constants.MORPHO_LLTV
        });
    }
    
    function getWbtcMarket() public pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: Constants.USDC,
            collateralToken: Constants.WBTC,
            oracle: Constants.WBTC_ORACLE,
            irm: Constants.IRM,
            lltv: Constants.MORPHO_LLTV
        });
    }
    
    /// @notice Get position details for an account in a market
    /// @param account The account to query
    /// @param marketParams The market parameters
    /// @return position The position details
    function getPosition(
        address account,
        MarketParams memory marketParams
    ) external view returns (Position memory position) {
        bytes32 marketId = marketParams.id();
        return MORPHO.position(marketId, account);
    }
    
    /// @notice Get position value in USDC
    /// @param account The account to query
    /// @param marketParams The market parameters
    /// @return collateralValue Value of collateral in USDC
    /// @return debtValue Value of debt in USDC
    function getPositionValue(
        address account,
        MarketParams memory marketParams
    ) external view returns (uint256 collateralValue, uint256 debtValue) {
        bytes32 marketId = marketParams.id();
        Position memory position = MORPHO.position(marketId, account);
        
        if (position.collateral > 0) {
            uint256 price = IOracle(marketParams.oracle).price();
            // Price is in 36 decimals, adjust for token decimals
            if (marketParams.collateralToken == Constants.WETH) {
                // WETH: 18 decimals, USDC: 6 decimals
                // collateral * price / 1e36 / 1e18 * 1e6 = collateral * price / 1e48 * 1e6
                collateralValue = (position.collateral * price) / 1e30;
            } else if (marketParams.collateralToken == Constants.WBTC) {
                // WBTC: 8 decimals, USDC: 6 decimals  
                // collateral * price / 1e36 / 1e8 * 1e6 = collateral * price / 1e38
                collateralValue = (position.collateral * price) / 1e38;
            }
        }
        
        if (position.borrowShares > 0) {
            Market memory market = MORPHO.market(marketId);
            // Convert shares to assets (already in USDC)
            debtValue = (position.borrowShares * market.totalBorrowAssets) / market.totalBorrowShares;
        }
    }
    
    /// @notice Calculate maximum borrowable amount
    /// @param collateralAmount Amount of collateral
    /// @param marketParams The market parameters
    /// @return maxBorrow Maximum USDC that can be borrowed
    function calculateMaxBorrow(
        uint256 collateralAmount,
        MarketParams memory marketParams
    ) external view returns (uint256 maxBorrow) {
        uint256 price = IOracle(marketParams.oracle).price();
        
        // Calculate collateral value in USDC
        uint256 collateralValue;
        if (marketParams.collateralToken == Constants.WETH) {
            collateralValue = (collateralAmount * price) / 1e30;
        } else if (marketParams.collateralToken == Constants.WBTC) {
            collateralValue = (collateralAmount * price) / 1e38;
        }
        
        // Apply LLTV
        maxBorrow = (collateralValue * marketParams.lltv) / 1e18;
    }
    
    /// @notice Get current utilization rate for a market
    /// @param marketParams The market parameters
    /// @return utilization The utilization rate (1e18 = 100%)
    function getMarketUtilization(
        MarketParams memory marketParams
    ) external view returns (uint256 utilization) {
        bytes32 marketId = marketParams.id();
        Market memory market = MORPHO.market(marketId);
        
        if (market.totalSupplyAssets == 0) return 0;
        
        utilization = (market.totalBorrowAssets * 1e18) / market.totalSupplyAssets;
    }
    
    /// @notice Get available liquidity in a market
    /// @param marketParams The market parameters
    /// @return available Available USDC to borrow
    function getAvailableLiquidity(
        MarketParams memory marketParams
    ) external view returns (uint256 available) {
        bytes32 marketId = marketParams.id();
        Market memory market = MORPHO.market(marketId);
        
        available = market.totalSupplyAssets - market.totalBorrowAssets;
    }
    
    /// @notice Check if a position would be healthy after an action
    /// @param account The account to check
    /// @param marketParams The market parameters
    /// @param additionalBorrow Additional USDC to borrow
    /// @param collateralToRemove Collateral to remove
    /// @return isHealthy Whether position would remain healthy
    function checkHealthAfterAction(
        address account,
        MarketParams memory marketParams,
        uint256 additionalBorrow,
        uint256 collateralToRemove
    ) external view returns (bool isHealthy) {
        bytes32 marketId = marketParams.id();
        Position memory position = MORPHO.position(marketId, account);
        Market memory market = MORPHO.market(marketId);
        
        // Calculate new collateral
        uint256 newCollateral = position.collateral - collateralToRemove;
        
        // Calculate new debt
        uint256 currentDebt = (position.borrowShares * market.totalBorrowAssets) / market.totalBorrowShares;
        uint256 newDebt = currentDebt + additionalBorrow;
        
        // Calculate collateral value
        uint256 price = IOracle(marketParams.oracle).price();
        uint256 collateralValue;
        if (marketParams.collateralToken == Constants.WETH) {
            collateralValue = (newCollateral * price) / 1e30;
        } else if (marketParams.collateralToken == Constants.WBTC) {
            collateralValue = (newCollateral * price) / 1e38;
        }
        
        // Check against LLTV
        uint256 maxDebt = (collateralValue * marketParams.lltv) / 1e18;
        isHealthy = newDebt <= maxDebt;
    }
}