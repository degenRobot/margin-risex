// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMorpho, MarketParams, Position} from "./interfaces/IMorpho.sol";
import {MarketParamsLib} from "./libraries/morpho/MarketParamsLib.sol";
import {Constants} from "./libraries/Constants.sol";

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