// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Morpho Market configuration parameters
struct MarketParams {
    address loanToken;       // Token to borrow (USDC)
    address collateralToken; // Token to use as collateral (WETH, WBTC, etc)
    address oracle;          // Price oracle for the market
    address irm;            // Interest Rate Model
    uint256 lltv;           // Liquidation Loan-To-Value ratio (18 decimals)
}

/// @notice User position in a Morpho market
struct Position {
    uint256 supplyShares;   // Lending position shares
    uint128 borrowShares;   // Borrowing position shares  
    uint128 collateral;     // Collateral deposited
}

/// @notice Market state information
struct Market {
    uint128 totalSupplyAssets;  // Total assets supplied
    uint128 totalSupplyShares;  // Total supply shares
    uint128 totalBorrowAssets;  // Total assets borrowed
    uint128 totalBorrowShares;  // Total borrow shares
    uint128 lastUpdate;         // Last interest accrual timestamp
    uint128 fee;                // Protocol fee
}

/// @title IMorpho
/// @notice Minimal interface for Morpho Blue lending protocol
/// @dev Only includes functions needed for portfolio margin integration
interface IMorpho {
    
    /// @notice Creates a new lending market
    /// @param marketParams Market configuration
    function createMarket(MarketParams memory marketParams) external;
    
    /// @notice Supply assets to a market
    /// @param marketParams The market to supply to
    /// @param assets Amount of assets to supply
    /// @param shares Amount of shares to mint (use 0)
    /// @param onBehalf Address that will own the position
    /// @param data Callback data (use empty bytes)
    /// @return assetsSupplied Actual amount supplied
    /// @return sharesSupplied Shares minted
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);
    
    /// @notice Supply collateral to a market
    /// @param marketParams The market to supply to
    /// @param assets Amount of collateral to supply
    /// @param onBehalf Address that will own the collateral
    /// @param data Callback data (use empty bytes)
    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes memory data
    ) external;
    
    /// @notice Withdraw collateral from a market
    /// @param marketParams The market to withdraw from
    /// @param assets Amount of collateral to withdraw
    /// @param onBehalf Owner of the collateral
    /// @param receiver Address to receive the collateral
    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external;
    
    /// @notice Borrow assets from a market
    /// @param marketParams The market to borrow from
    /// @param assets Amount to borrow (use this, not shares)
    /// @param shares Amount of shares to mint (use 0)
    /// @param onBehalf Address that will owe the debt
    /// @param receiver Address to receive the borrowed assets
    /// @return assetsBorrowed Actual amount borrowed
    /// @return sharesBorrowed Shares minted
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed);
    
    /// @notice Repay borrowed assets
    /// @param marketParams The market to repay to
    /// @param assets Amount to repay (use this, not shares)
    /// @param shares Shares to burn (use 0)
    /// @param onBehalf Owner of the debt
    /// @param data Callback data (use empty bytes)
    /// @return assetsRepaid Actual amount repaid
    /// @return sharesRepaid Shares burned
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsRepaid, uint256 sharesRepaid);
    
    /// @notice Get user position in a market
    /// @param id Market ID (hash of MarketParams)
    /// @param user Address to query
    /// @return User's position
    function position(bytes32 id, address user) external view returns (Position memory);
    
    /// @notice Get market state
    /// @param id Market ID (hash of MarketParams)
    /// @return Market state
    function market(bytes32 id) external view returns (Market memory);
    
    /// @notice Check if a market ID exists
    /// @param id Market ID to check
    /// @return Market parameters
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    
    /// @notice Accrue interest for a market
    /// @param marketParams Market to accrue interest for
    function accrueInterest(MarketParams memory marketParams) external;
}