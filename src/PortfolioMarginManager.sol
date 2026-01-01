// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PortfolioSubAccount} from "./PortfolioSubAccount.sol";
import {MorphoAdapter} from "./adapters/MorphoAdapter.sol";
import {Constants} from "./libraries/Constants.sol";
import {MarketParams, Position} from "./interfaces/IMorpho.sol";
import {MarketParamsLib} from "./libraries/morpho/MarketParamsLib.sol";

/// @title PortfolioMarginManager
/// @notice Manager for portfolio margin system - creates sub-accounts and provides view functions
/// @dev Simplified version without complex health calculations or liquidations
contract PortfolioMarginManager is Ownable {
    using MarketParamsLib for MarketParams;
    
    /// @notice User address to sub-account mapping
    mapping(address => address) public userSubAccounts;
    
    /// @notice Sub-account to user mapping  
    mapping(address => address) public subAccountUsers;
    
    /// @notice All deployed sub-accounts
    address[] public allSubAccounts;
    
    /// @notice Morpho adapter for helper functions
    MorphoAdapter public immutable morphoAdapter;
    
    /// @notice Events
    event SubAccountCreated(address indexed user, address indexed subAccount);
    
    constructor() Ownable() {
        morphoAdapter = new MorphoAdapter();
    }
    
    // ========== SUB-ACCOUNT MANAGEMENT ==========
    
    /// @notice Create a new sub-account for a user
    /// @param user User address
    /// @return subAccount The created sub-account address
    function createSubAccount(address user) external returns (address subAccount) {
        require(user != address(0), "Invalid user");
        require(userSubAccounts[user] == address(0), "Already has sub-account");
        
        // Deploy new sub-account contract
        subAccount = address(new PortfolioSubAccount(user, address(this)));
        
        // Update mappings
        userSubAccounts[user] = subAccount;
        subAccountUsers[subAccount] = user;
        allSubAccounts.push(subAccount);
        
        emit SubAccountCreated(user, subAccount);
    }
    
    /// @notice Get or create sub-account for a user
    /// @param user User address
    /// @return subAccount The sub-account address
    function getOrCreateSubAccount(address user) external returns (address subAccount) {
        subAccount = userSubAccounts[user];
        if (subAccount == address(0)) {
            return this.createSubAccount(user);
        }
    }
    
    // ========== VIEW FUNCTIONS - MORPHO ==========
    
    /// @notice Get Morpho positions for a user across all markets
    /// @param user User address
    /// @return wethCollateral WETH collateral amount
    /// @return wethDebt WETH market debt in USDC
    /// @return wbtcCollateral WBTC collateral amount  
    /// @return wbtcDebt WBTC market debt in USDC
    function getMorphoPositions(address user) external view returns (
        uint256 wethCollateral,
        uint256 wethDebt,
        uint256 wbtcCollateral,
        uint256 wbtcDebt
    ) {
        address subAccount = userSubAccounts[user];
        if (subAccount == address(0)) return (0, 0, 0, 0);
        
        // Get WETH market position
        MarketParams memory wethMarket = morphoAdapter.getWethMarket();
        Position memory wethPos = PortfolioSubAccount(subAccount).getMorphoPosition(wethMarket.id());
        wethCollateral = wethPos.collateral;
        
        // Get WBTC market position
        MarketParams memory wbtcMarket = morphoAdapter.getWbtcMarket();
        Position memory wbtcPos = PortfolioSubAccount(subAccount).getMorphoPosition(wbtcMarket.id());
        wbtcCollateral = wbtcPos.collateral;
        
        // Get debt values
        (, wethDebt) = morphoAdapter.getPositionValue(subAccount, wethMarket);
        (, wbtcDebt) = morphoAdapter.getPositionValue(subAccount, wbtcMarket);
    }
    
    /// @notice Get Morpho position values in USDC
    /// @param user User address
    /// @return totalCollateralValue Total collateral value in USDC
    /// @return totalDebtValue Total debt value in USDC
    function getMorphoValues(address user) external view returns (
        uint256 totalCollateralValue,
        uint256 totalDebtValue
    ) {
        address subAccount = userSubAccounts[user];
        if (subAccount == address(0)) return (0, 0);
        
        // Get WETH market values
        MarketParams memory wethMarket = morphoAdapter.getWethMarket();
        (uint256 wethColValue, uint256 wethDebtValue) = morphoAdapter.getPositionValue(subAccount, wethMarket);
        
        // Get WBTC market values
        MarketParams memory wbtcMarket = morphoAdapter.getWbtcMarket();
        (uint256 wbtcColValue, uint256 wbtcDebtValue) = morphoAdapter.getPositionValue(subAccount, wbtcMarket);
        
        totalCollateralValue = wethColValue + wbtcColValue;
        totalDebtValue = wethDebtValue + wbtcDebtValue;
    }
    
    // ========== VIEW FUNCTIONS - RISEX ==========
    
    /// @notice Get RISEx account status
    /// @param user User address
    /// @return equity Account equity in RISEx
    /// @return hasAccount Whether account exists in RISEx
    function getRISExStatus(address user) external view returns (
        int256 equity,
        bool hasAccount
    ) {
        address subAccount = userSubAccounts[user];
        if (subAccount == address(0)) return (0, false);
        
        return PortfolioSubAccount(subAccount).getRISExEquity();
    }
    
    // ========== VIEW FUNCTIONS - BALANCES ==========
    
    /// @notice Get token balances in sub-account
    /// @param user User address
    /// @return usdcBalance USDC balance
    /// @return wethBalance WETH balance
    /// @return wbtcBalance WBTC balance
    function getSubAccountBalances(address user) external view returns (
        uint256 usdcBalance,
        uint256 wethBalance,
        uint256 wbtcBalance
    ) {
        address subAccount = userSubAccounts[user];
        if (subAccount == address(0)) return (0, 0, 0);
        
        PortfolioSubAccount account = PortfolioSubAccount(subAccount);
        usdcBalance = account.getBalance(Constants.USDC);
        wethBalance = account.getBalance(Constants.WETH);
        wbtcBalance = account.getBalance(Constants.WBTC);
    }
    
    // ========== UTILITY FUNCTIONS ==========
    
    /// @notice Get total number of sub-accounts
    function getTotalSubAccounts() external view returns (uint256) {
        return allSubAccounts.length;
    }
    
    /// @notice Check if a user has a sub-account
    function hasSubAccount(address user) external view returns (bool) {
        return userSubAccounts[user] != address(0);
    }
    
    /// @notice Get sub-account by index
    function getSubAccountByIndex(uint256 index) external view returns (address) {
        return allSubAccounts[index];
    }
    
    /// @notice Get market parameters
    function getMarketParams() external view returns (
        MarketParams memory wethMarket,
        MarketParams memory wbtcMarket
    ) {
        wethMarket = morphoAdapter.getWethMarket();
        wbtcMarket = morphoAdapter.getWbtcMarket();
    }
}