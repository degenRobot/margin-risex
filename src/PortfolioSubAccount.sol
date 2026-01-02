// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMorpho, MarketParams, Position, Market} from "./interfaces/IMorpho.sol";
import {MarketParamsLib} from "./libraries/morpho/MarketParamsLib.sol";
import {Constants} from "./libraries/Constants.sol";

/// @notice Minimal interface for Morpho price oracles
interface IMorphoOracle {
    function price() external view returns (uint256);
}

/// @title PortfolioSubAccount
/// @notice User sub-account for portfolio margin trading with Morpho and RISEx
/// @dev Non-proxy implementation with manager-based access control
contract PortfolioSubAccount {
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;
    
    /// @notice Portfolio margin manager that controls this account
    address public immutable manager;
    
    /// @notice The user who owns this sub-account
    address public owner;
    
    /// @notice Morpho Blue contract
    IMorpho public constant MORPHO = IMorpho(Constants.MORPHO);
    
    /// @notice RISEx PerpsManager (skip Deposit contract which mints)
    IPerpsManager public constant PERPS_MANAGER = IPerpsManager(Constants.RISEX_PERPS_MANAGER);
    
    /// @notice USDC token
    IERC20 public constant USDC = IERC20(Constants.USDC);
    
    /// @notice Check if caller is owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    /// @notice Check if caller is manager
    modifier onlyManager() {
        require(msg.sender == manager, "Only manager");
        _;
    }
    
    /// @notice Check if caller is owner or manager
    modifier onlyOwnerOrManager() {
        require(msg.sender == owner || msg.sender == manager, "Only owner or manager");
        _;
    }
    
    /// @notice Events
    event CollateralSupplied(bytes32 indexed marketId, uint256 amount);
    event CollateralWithdrawn(bytes32 indexed marketId, uint256 amount);
    event USDCBorrowed(bytes32 indexed marketId, uint256 amount);
    event USDCRepaid(bytes32 indexed marketId, uint256 amount);
    event RISExDeposit(uint256 amount, bool success);
    event RISExWithdrawal(address token, uint256 amount);
    event OrderPlaced(bytes orderData);
    
    constructor(address _owner, address _manager) {
        require(_owner != address(0), "Invalid owner");
        require(_manager != address(0), "Invalid manager");
        owner = _owner;
        manager = _manager;
    }
    
    // ========== MORPHO FUNCTIONS ==========
    
    /// @notice Supply collateral to Morpho market
    /// @param marketParams Market parameters  
    /// @param amount Amount of collateral to supply
    function supplyToMorpho(
        MarketParams calldata marketParams,
        uint256 amount
    ) external onlyOwnerOrManager {
        // Transfer collateral from caller to this account
        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve Morpho
        IERC20(marketParams.collateralToken).safeApprove(address(MORPHO), amount);
        
        // Supply collateral
        MORPHO.supplyCollateral(marketParams, amount, address(this), "");
        
        emit CollateralSupplied(marketParams.id(), amount);
    }
    
    /// @notice Borrow USDC from Morpho
    /// @param marketParams Market parameters
    /// @param amount Amount of USDC to borrow
    function borrowFromMorpho(
        MarketParams calldata marketParams,
        uint256 amount
    ) external onlyOwnerOrManager {
        require(marketParams.loanToken == address(USDC), "Can only borrow USDC");
        
        // Borrow USDC to this account (funds stay internal)
        (uint256 borrowed,) = MORPHO.borrow(
            marketParams,
            amount,
            0, // shares
            address(this), // onBehalf
            address(this)  // receiver - IMPORTANT: keep funds in sub-account
        );
        
        emit USDCBorrowed(marketParams.id(), borrowed);
    }
    
    /// @notice Withdraw collateral from Morpho
    /// @param marketParams Market parameters
    /// @param amount Amount to withdraw
    /// @param to Recipient (owner or manager for liquidations)
    function withdrawFromMorpho(
        MarketParams calldata marketParams,
        uint256 amount,
        address to
    ) external onlyOwnerOrManager {
        // Only owner can withdraw to arbitrary address
        if (msg.sender == owner) {
            require(to == owner, "Owner can only withdraw to self");
        }
        
        // Withdraw collateral
        MORPHO.withdrawCollateral(marketParams, amount, address(this), to);
        
        emit CollateralWithdrawn(marketParams.id(), amount);
    }
    
    /// @notice Repay USDC debt to Morpho
    /// @param marketParams Market parameters
    /// @param amount Amount to repay (type(uint256).max for full repayment)
    function repayToMorpho(
        MarketParams calldata marketParams,
        uint256 amount
    ) external onlyOwnerOrManager {
        require(marketParams.loanToken == address(USDC), "Can only repay USDC");
        
        // If repaying max, get actual debt amount
        if (amount == type(uint256).max) {
            Position memory pos = MORPHO.position(marketParams.id(), address(this));
            if (pos.borrowShares == 0) return;
        }
        
        // Transfer USDC from caller
        USDC.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve Morpho
        USDC.safeApprove(address(MORPHO), amount);
        
        // Repay debt
        (uint256 repaid,) = MORPHO.repay(marketParams, amount, 0, address(this), "");
        
        // Return excess if any
        if (amount > repaid && repaid > 0) {
            USDC.safeTransfer(msg.sender, amount - repaid);
        }
        
        emit USDCRepaid(marketParams.id(), repaid);
    }
    
    // ========== RISEX FUNCTIONS ==========
    
    /// @notice Deposit USDC to RISEx
    /// @param amount Amount of USDC to deposit (6 decimals)
    function depositToRISEx(uint256 amount) external onlyOwnerOrManager {
        require(USDC.balanceOf(address(this)) >= amount, "Insufficient USDC");
        
        // Approve PerpsManager directly (skip Deposit contract)
        USDC.approve(address(PERPS_MANAGER), amount);
        
        // Deposit directly to PerpsManager
        // NOTE: This will revert with NotActivated but actually succeeds on testnet
        try PERPS_MANAGER.deposit(address(this), address(USDC), amount) {
            emit RISExDeposit(amount, true);
        } catch {
            // Check if deposit actually succeeded despite revert
            emit RISExDeposit(amount, false);
            USDC.approve(address(PERPS_MANAGER), 0);
        }
    }
    
    /// @notice Withdraw from RISEx
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    function withdrawFromRISEx(address token, uint256 amount) external onlyOwnerOrManager {
        // Withdraw to the caller (owner or manager during liquidation)
        PERPS_MANAGER.withdraw(msg.sender, token, amount);
        emit RISExWithdrawal(token, amount);
    }
    
    /// @notice Place order on RISEx
    /// @param orderData Encoded order data
    function placeOrder(bytes calldata orderData) external onlyOwnerOrManager {
        // Place order on RISEx
        PERPS_MANAGER.placeOrder(orderData);
        emit OrderPlaced(orderData);
    }
    
    /// @notice Cancel order on RISEx
    /// @param cancelData Cancel order data
    function cancelOrder(bytes32 cancelData) external onlyOwnerOrManager {
        PERPS_MANAGER.cancelOrder(cancelData);
    }
    
    // ========== COMBINED OPERATIONS ==========
    
    /// @notice Lend collateral and open position in one transaction
    /// @param marketParams Morpho market parameters
    /// @param collateralAmount Amount of collateral to supply
    /// @param borrowAmount Amount of USDC to borrow
    /// @param orderData Encoded order data for RISEx position
    function openPositionWithCollateral(
        MarketParams calldata marketParams,
        uint256 collateralAmount,
        uint256 borrowAmount,
        bytes calldata orderData
    ) external onlyOwner {
        // 1. Supply collateral to Morpho
        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        IERC20(marketParams.collateralToken).safeApprove(address(MORPHO), collateralAmount);
        MORPHO.supplyCollateral(marketParams, collateralAmount, address(this), "");
        emit CollateralSupplied(marketParams.id(), collateralAmount);
        
        // 2. Borrow USDC from Morpho
        require(marketParams.loanToken == address(USDC), "Can only borrow USDC");
        (uint256 borrowed,) = MORPHO.borrow(
            marketParams,
            borrowAmount,
            0,
            address(this),
            address(this)
        );
        emit USDCBorrowed(marketParams.id(), borrowed);
        
        // 3. Deposit USDC to RISEx (up to borrowed amount)
        uint256 depositAmount = borrowed > borrowAmount ? borrowAmount : borrowed;
        if (depositAmount > 0) {
            USDC.approve(address(PERPS_MANAGER), depositAmount);
            try PERPS_MANAGER.deposit(address(this), address(USDC), depositAmount) {
                emit RISExDeposit(depositAmount, true);
            } catch {
                emit RISExDeposit(depositAmount, false);
                USDC.approve(address(PERPS_MANAGER), 0);
            }
        }
        
        // 4. Place order on RISEx
        PERPS_MANAGER.placeOrder(orderData);
        emit OrderPlaced(orderData);
    }
    
    /// @notice Close position and withdraw funds in one transaction
    /// @param marketParams Morpho market parameters
    /// @param closeOrderData Order data to close RISEx position
    /// @param withdrawAmount Amount to withdraw from RISEx
    /// @param repayAll Whether to repay all Morpho debt
    function closePositionAndWithdraw(
        MarketParams calldata marketParams,
        bytes calldata closeOrderData,
        uint256 withdrawAmount,
        bool repayAll
    ) external onlyOwner {
        // 1. Close position on RISEx
        PERPS_MANAGER.placeOrder(closeOrderData);
        emit OrderPlaced(closeOrderData);
        
        // 2. Withdraw USDC from RISEx to this account
        if (withdrawAmount > 0) {
            PERPS_MANAGER.withdraw(address(this), address(USDC), withdrawAmount);
            emit RISExWithdrawal(address(USDC), withdrawAmount);
        }
        
        // 3. Repay Morpho debt
        Position memory pos = MORPHO.position(marketParams.id(), address(this));
        if (pos.borrowShares > 0) {
            uint256 repayAmount = repayAll ? type(uint256).max : USDC.balanceOf(address(this));
            if (repayAmount > 0) {
                USDC.safeApprove(address(MORPHO), repayAmount);
                (uint256 repaid,) = MORPHO.repay(marketParams, repayAmount, 0, address(this), "");
                emit USDCRepaid(marketParams.id(), repaid);
            }
        }
        
        // 4. If all debt repaid, withdraw collateral to owner
        pos = MORPHO.position(marketParams.id(), address(this));
        if (pos.borrowShares == 0 && pos.collateral > 0) {
            MORPHO.withdrawCollateral(marketParams, pos.collateral, address(this), owner);
            emit CollateralWithdrawn(marketParams.id(), pos.collateral);
        }
    }
    
    /// @notice Rebalance position based on Morpho LTV
    /// @param marketParams Morpho market parameters
    /// @param orderData Order data for RISEx adjustment
    /// @param targetLTV Target loan-to-value ratio (in basis points, e.g., 5000 = 50%)
    function rebalancePosition(
        MarketParams calldata marketParams,
        bytes calldata orderData,
        uint256 targetLTV
    ) external onlyOwner {
        // Get current Morpho position
        Position memory pos = MORPHO.position(marketParams.id(), address(this));
        require(pos.collateral > 0, "No collateral");
        
        // Calculate current and target values
        uint256 collateralValue = _getCollateralValue(marketParams, pos.collateral);
        uint256 currentDebt = _getDebtValue(marketParams, pos.borrowShares);
        uint256 targetDebt = (collateralValue * targetLTV) / 10000;
        
        if (targetDebt > currentDebt) {
            // Need to increase position: borrow more and deposit to RISEx
            uint256 borrowAmount = targetDebt - currentDebt;
            
            // Borrow additional USDC
            (uint256 borrowed,) = MORPHO.borrow(
                marketParams,
                borrowAmount,
                0,
                address(this),
                address(this)
            );
            emit USDCBorrowed(marketParams.id(), borrowed);
            
            // Deposit to RISEx
            if (borrowed > 0) {
                USDC.approve(address(PERPS_MANAGER), borrowed);
                try PERPS_MANAGER.deposit(address(this), address(USDC), borrowed) {
                    emit RISExDeposit(borrowed, true);
                } catch {
                    emit RISExDeposit(borrowed, false);
                    USDC.approve(address(PERPS_MANAGER), 0);
                }
            }
            
            // Place order to increase position
            PERPS_MANAGER.placeOrder(orderData);
            emit OrderPlaced(orderData);
            
        } else if (targetDebt < currentDebt) {
            // Need to decrease position: close some position and repay debt
            uint256 repayAmount = currentDebt - targetDebt;
            
            // Place order to reduce position
            PERPS_MANAGER.placeOrder(orderData);
            emit OrderPlaced(orderData);
            
            // Withdraw USDC from RISEx
            PERPS_MANAGER.withdraw(address(this), address(USDC), repayAmount);
            emit RISExWithdrawal(address(USDC), repayAmount);
            
            // Repay debt to Morpho
            uint256 availableUSDC = USDC.balanceOf(address(this));
            uint256 actualRepay = availableUSDC > repayAmount ? repayAmount : availableUSDC;
            if (actualRepay > 0) {
                USDC.safeApprove(address(MORPHO), actualRepay);
                (uint256 repaid,) = MORPHO.repay(marketParams, actualRepay, 0, address(this), "");
                emit USDCRepaid(marketParams.id(), repaid);
            }
        }
    }
    
    /// @notice Helper to get collateral value in USDC
    function _getCollateralValue(MarketParams memory marketParams, uint256 collateralAmount) internal view returns (uint256) {
        uint256 price = IMorphoOracle(marketParams.oracle).price();
        // Price conversion depends on collateral decimals
        if (marketParams.collateralToken == Constants.WETH) {
            return (collateralAmount * price) / 1e36; // WETH: 18 decimals
        } else if (marketParams.collateralToken == Constants.WBTC) {
            return (collateralAmount * price) / 1e26; // WBTC: 8 decimals
        }
        revert("Unsupported collateral");
    }
    
    /// @notice Helper to get debt value from shares
    function _getDebtValue(MarketParams memory marketParams, uint256 borrowShares) internal view returns (uint256) {
        if (borrowShares == 0) return 0;
        Market memory marketData = MORPHO.market(marketParams.id());
        if (marketData.totalBorrowShares == 0) return 0;
        return (borrowShares * marketData.totalBorrowAssets) / marketData.totalBorrowShares;
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /// @notice Get Morpho position
    /// @param marketId Market ID
    /// @return Position data
    function getMorphoPosition(bytes32 marketId) external view returns (Position memory) {
        return MORPHO.position(marketId, address(this));
    }
    
    /// @notice Get RISEx account equity
    /// @return equity Account equity (can be negative)
    /// @return hasAccount Whether account exists in RISEx
    function getRISExEquity() external view returns (int256 equity, bool hasAccount) {
        try PERPS_MANAGER.getAccountEquity(address(this)) returns (int256 _equity) {
            return (_equity, true);
        } catch {
            return (0, false);
        }
    }
    
    /// @notice Get token balance
    /// @param token Token address
    /// @return Balance
    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    // ========== EMERGENCY FUNCTIONS ==========
    
    /// @notice Emergency token rescue (only manager)
    /// @param token Token to rescue
    /// @param to Recipient
    /// @param amount Amount to rescue
    function rescueToken(address token, address to, uint256 amount) external onlyManager {
        IERC20(token).safeTransfer(to, amount);
    }
}

/// @notice Minimal RISEx interface
interface IPerpsManager {
    function deposit(address to, address token, uint256 amount) external;
    function withdraw(address to, address token, uint256 amount) external;
    function placeOrder(bytes calldata orderData) external returns (uint256);
    function cancelOrder(bytes32 cancelData) external;
    function getAccountEquity(address account) external view returns (int256);
}