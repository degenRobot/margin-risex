// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams, Id, Market, Position} from "morpho-blue/interfaces/IMorpho.sol";
import {MarketParamsLib} from "morpho-blue/libraries/MarketParamsLib.sol";
import {IOracle} from "morpho-blue/interfaces/IOracle.sol";
import {IRISExPerpsManager} from "./interfaces/IRISExPerpsManager.sol";
import {PortfolioSubAccount} from "./PortfolioSubAccount.sol";

/// @title PortfolioMarginManager
/// @notice Central manager for portfolio margin system
/// @dev Manages sub-accounts, risk parameters, and liquidations
contract PortfolioMarginManager is Ownable {
    using MarketParamsLib for MarketParams;
    
    /// @notice Morpho Blue contract
    IMorpho public immutable MORPHO;
    
    /// @notice RISEx Perps Manager contract
    IRISExPerpsManager public immutable RISEX;
    
    /// @notice Portfolio sub-account implementation
    address public immutable SUB_ACCOUNT_IMPL;
    
    /// @notice User address to sub-account mapping
    mapping(address => address) public userSubAccounts;
    
    /// @notice Sub-account to user mapping  
    mapping(address => address) public subAccountUsers;
    
    /// @notice Supported Morpho market configurations
    mapping(Id => MarketConfig) public marketConfigs;
    
    /// @notice List of supported market IDs
    Id[] public supportedMarkets;
    
    /// @notice Liquidation threshold (scaled by 1e18, e.g., 0.95e18 = 95%)
    uint256 public constant LIQUIDATION_THRESHOLD = 0.95e18;
    
    /// @notice Minimum health factor for new actions (scaled by 1e18)
    uint256 public constant MIN_HEALTH_FOR_ACTIONS = 1.05e18;
    
    /// @notice Liquidation incentive (scaled by 1e18, e.g., 0.05e18 = 5%)
    uint256 public constant LIQUIDATION_INCENTIVE = 0.05e18;
    
    /// @notice Market configuration
    struct MarketConfig {
        bool isSupported;
        uint256 collateralFactor; // How much of collateral value counts (e.g., 0.9e18 = 90%)
        MarketParams params;
    }
    
    /// @notice Portfolio health status
    struct HealthStatus {
        uint256 totalCollateralValue;
        uint256 totalDebtValue;
        int256 risexEquity;
        uint256 healthFactor;
        bool isHealthy;
    }
    
    /// @notice Emitted when a new sub-account is created
    event SubAccountCreated(address indexed user, address indexed subAccount);
    
    /// @notice Emitted when a market is added
    event MarketAdded(Id indexed marketId, uint256 collateralFactor);
    
    /// @notice Emitted when a portfolio is liquidated
    event PortfolioLiquidated(address indexed user, address indexed liquidator, uint256 incentive);
    
    constructor(address _morpho, address _risex) {
        MORPHO = IMorpho(_morpho);
        RISEX = IRISExPerpsManager(_risex);
        
        // Deploy sub-account implementation
        SUB_ACCOUNT_IMPL = address(new PortfolioSubAccount(
            address(this),
            _morpho,
            _risex
        ));
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // SUB-ACCOUNT MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Create a new sub-account for a user
    /// @param user User address
    /// @return subAccount The created sub-account address
    function createSubAccount(address user) external returns (address subAccount) {
        require(user != address(0), "Invalid user");
        require(userSubAccounts[user] == address(0), "Already has sub-account");
        
        // Deploy minimal proxy
        subAccount = Clones.cloneDeterministic(
            SUB_ACCOUNT_IMPL,
            keccak256(abi.encodePacked(user, block.chainid))
        );
        
        // Initialize the sub-account
        PortfolioSubAccount(subAccount).initialize(user);
        
        // Update mappings
        userSubAccounts[user] = subAccount;
        subAccountUsers[subAccount] = user;
        
        emit SubAccountCreated(user, subAccount);
    }
    
    /// @notice Get or create sub-account for a user
    /// @param user User address
    /// @return subAccount The sub-account address
    function getOrCreateSubAccount(address user) external returns (address subAccount) {
        subAccount = userSubAccounts[user];
        if (subAccount == address(0)) {
            subAccount = this.createSubAccount(user);
        }
    }
    
    /// @notice Predict sub-account address for a user
    /// @param user User address
    /// @return The predicted sub-account address
    function predictSubAccountAddress(address user) external view returns (address) {
        return Clones.predictDeterministicAddress(
            SUB_ACCOUNT_IMPL,
            keccak256(abi.encodePacked(user, block.chainid))
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MARKET CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Add a supported Morpho market
    /// @param marketParams Market parameters
    /// @param collateralFactor Collateral factor for risk calculations
    function addMarket(
        MarketParams calldata marketParams,
        uint256 collateralFactor
    ) external onlyOwner {
        require(collateralFactor <= 1e18, "Invalid collateral factor");
        
        Id marketId = marketParams.id();
        require(!marketConfigs[marketId].isSupported, "Already supported");
        
        marketConfigs[marketId] = MarketConfig({
            isSupported: true,
            collateralFactor: collateralFactor,
            params: marketParams
        });
        
        supportedMarkets.push(marketId);
        
        emit MarketAdded(marketId, collateralFactor);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // HEALTH CALCULATIONS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Get portfolio health status for a user
    /// @param user User address
    /// @return status Health status struct
    function getPortfolioHealth(address user) public view returns (HealthStatus memory status) {
        address subAccount = userSubAccounts[user];
        if (subAccount == address(0)) {
            status.healthFactor = type(uint256).max;
            status.isHealthy = true;
            return status;
        }
        
        // Calculate Morpho positions value
        for (uint256 i = 0; i < supportedMarkets.length; i++) {
            Id marketId = supportedMarkets[i];
            MarketConfig memory config = marketConfigs[marketId];
            
            Position memory position = MORPHO.position(marketId, subAccount);
            
            // Get collateral value
            if (position.collateral > 0) {
                uint256 collateralPrice = IOracle(config.params.oracle).price();
                // Price is scaled by 1e36, adjust for token decimals
                uint256 collateralValue = (position.collateral * collateralPrice * config.collateralFactor) / 1e36 / 1e18;
                status.totalCollateralValue += collateralValue;
            }
            
            // Get debt value
            if (position.borrowShares > 0) {
                Market memory market = MORPHO.market(marketId);
                // Convert shares to assets
                uint256 borrowedAssets = (position.borrowShares * market.totalBorrowAssets) / market.totalBorrowShares;
                status.totalDebtValue += borrowedAssets;
            }
        }
        
        // Get RISEx equity
        status.risexEquity = RISEX.getAccountEquity(subAccount);
        
        // Calculate health factor
        // Health = (CollateralValue + RISExEquity - Debt) / Debt
        if (status.totalDebtValue == 0) {
            status.healthFactor = type(uint256).max;
            status.isHealthy = true;
        } else {
            uint256 netValue = status.totalCollateralValue + (status.risexEquity > 0 ? uint256(status.risexEquity) : 0);
            if (netValue >= status.totalDebtValue) {
                status.healthFactor = ((netValue - status.totalDebtValue) * 1e18) / status.totalDebtValue;
                status.isHealthy = status.healthFactor >= LIQUIDATION_THRESHOLD;
            } else {
                // Underwater
                status.healthFactor = 0;
                status.isHealthy = false;
            }
        }
    }
    
    /// @notice Check if user's portfolio is healthy
    /// @param user User address
    /// @return Whether portfolio is healthy
    function isHealthy(address user) external view returns (bool) {
        return getPortfolioHealth(user).isHealthy;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // LIQUIDATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Liquidate an unhealthy portfolio
    /// @param user User whose portfolio to liquidate
    function liquidatePortfolio(address user) external {
        HealthStatus memory health = getPortfolioHealth(user);
        require(!health.isHealthy, "Portfolio is healthy");
        
        address subAccount = userSubAccounts[user];
        require(subAccount != address(0), "No sub-account");
        
        PortfolioSubAccount account = PortfolioSubAccount(subAccount);
        
        // Step 1: Force close all RISEx positions
        // This would require adding a forceClosePositions function to RISEx
        // For now, we'll withdraw available margin
        
        // First, get USDC address from any market config
        address usdcToken = address(0);
        for (uint256 i = 0; i < supportedMarkets.length; i++) {
            MarketConfig memory config = marketConfigs[supportedMarkets[i]];
            if (config.isSupported) {
                usdcToken = config.params.loanToken;
                break;
            }
        }
        
        uint256 usdcInRisex = RISEX.getWithdrawableAmount(subAccount, usdcToken);
        if (usdcInRisex > 0) {
            account.withdrawFromRisEx(usdcToken, usdcInRisex);
        }
        
        // Step 2: Repay Morpho debts with available USDC
        uint256 usdcBalance = IERC20(usdcToken).balanceOf(subAccount);
        if (usdcBalance > 0) {
            for (uint256 i = 0; i < supportedMarkets.length; i++) {
                Id marketId = supportedMarkets[i];
                MarketConfig memory config = marketConfigs[marketId];
                
                Position memory position = MORPHO.position(marketId, subAccount);
                if (position.borrowShares > 0) {
                    // Repay what we can
                    account.repayUSDC(config.params, usdcBalance);
                    usdcBalance = IERC20(usdcToken).balanceOf(subAccount);
                    if (usdcBalance == 0) break;
                }
            }
        }
        
        // Step 3: Seize collateral with liquidation incentive
        for (uint256 i = 0; i < supportedMarkets.length; i++) {
            Id marketId = supportedMarkets[i];
            MarketConfig memory config = marketConfigs[marketId];
            
            Position memory position = MORPHO.position(marketId, subAccount);
            if (position.collateral > 0) {
                // Calculate incentive amount
                uint256 incentiveAmount = (position.collateral * LIQUIDATION_INCENTIVE) / 1e18;
                uint256 liquidatorAmount = position.collateral - incentiveAmount;
                
                // Withdraw collateral
                account.withdrawCollateral(config.params, position.collateral);
                
                // Transfer to liquidator with incentive
                account.rescueToken(
                    config.params.collateralToken,
                    liquidatorAmount,
                    msg.sender
                );
                
                // Keep incentive as protocol fee
                if (incentiveAmount > 0) {
                    account.rescueToken(
                        config.params.collateralToken,
                        incentiveAmount,
                        owner()
                    );
                }
            }
        }
        
        emit PortfolioLiquidated(user, msg.sender, LIQUIDATION_INCENTIVE);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // VIEWS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Get number of supported markets
    /// @return Number of markets
    function getSupportedMarketsCount() external view returns (uint256) {
        return supportedMarkets.length;
    }
    
    /// @notice Get supported market by index
    /// @param index Market index
    /// @return marketId Market ID
    /// @return config Market configuration
    function getSupportedMarket(uint256 index) external view returns (Id marketId, MarketConfig memory config) {
        marketId = supportedMarkets[index];
        config = marketConfigs[marketId];
    }
}