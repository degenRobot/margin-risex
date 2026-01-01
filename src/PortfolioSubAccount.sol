// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMorpho, MarketParams, Position} from "./interfaces/IMorpho.sol";
import {MarketParamsLib} from "./libraries/morpho/MarketParamsLib.sol";
import {IRISExPerpsManager} from "./interfaces/IRISExPerpsManager.sol";
import {IDeposit} from "./interfaces/IDeposit.sol";

/// @title PortfolioSubAccount
/// @notice User-specific proxy account for portfolio margin trading
/// @dev Deployed as minimal proxy (EIP-1167) for each user
contract PortfolioSubAccount {
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;
    
    /// @notice Portfolio margin manager contract
    address public immutable MANAGER;
    
    /// @notice Morpho Blue contract
    IMorpho public immutable MORPHO;
    
    /// @notice RISEx Perps Manager contract  
    IRISExPerpsManager public immutable RISEX;
    
    /// @notice RISEx Deposit contract for USDC deposits
    address constant DEPOSIT_CONTRACT = 0x5BC20A936EfEE0d758A3c168d2f017c83805B986;
    
    /// @notice USDC token address on RISE testnet
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    
    /// @notice The user who owns this sub-account
    address public user;
    
    /// @notice Whether this account has been initialized
    bool public initialized;
    
    /// @dev Modifier to ensure only the owner can call
    modifier onlyUser() {
        require(msg.sender == user, "Only user");
        _;
    }
    
    /// @dev Modifier to ensure only the manager can call
    modifier onlyManager() {
        require(msg.sender == MANAGER, "Only manager");
        _;
    }
    
    /// @dev Modifier to ensure only user or manager can call
    modifier onlyUserOrManager() {
        require(msg.sender == user || msg.sender == MANAGER, "Only user or manager");
        _;
    }
    
    /// @notice Emitted when account is initialized
    event Initialized(address indexed user);
    
    /// @notice Emitted when collateral is deposited to Morpho
    event CollateralDeposited(bytes32 indexed marketId, address indexed token, uint256 amount);
    
    /// @notice Emitted when collateral is withdrawn from Morpho
    event CollateralWithdrawn(bytes32 indexed marketId, address indexed token, uint256 amount);
    
    /// @notice Emitted when USDC is borrowed from Morpho
    event USDCBorrowed(bytes32 indexed marketId, uint256 amount);
    
    /// @notice Emitted when USDC debt is repaid to Morpho
    event USDCRepaid(bytes32 indexed marketId, uint256 amount);
    
    /// @notice Constructor sets immutable addresses
    /// @param _manager Portfolio margin manager address
    /// @param _morpho Morpho Blue address
    /// @param _risex RISEx perps manager address
    constructor(address _manager, address _morpho, address _risex) {
        MANAGER = _manager;
        MORPHO = IMorpho(_morpho);
        RISEX = IRISExPerpsManager(_risex);
    }
    
    /// @notice Initialize the sub-account for a specific user
    /// @param _user The user who owns this account
    /// @dev Can only be called once by the manager
    function initialize(address _user) external onlyManager {
        require(!initialized, "Already initialized");
        require(_user != address(0), "Invalid user");
        
        initialized = true;
        user = _user;
        
        emit Initialized(_user);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // MORPHO INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Deposit collateral to a Morpho market
    /// @param marketParams Market parameters
    /// @param amount Amount of collateral to deposit
    function depositCollateral(
        MarketParams calldata marketParams,
        uint256 amount
    ) external onlyUser {
        // Transfer collateral from user to this account
        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve Morpho to spend the collateral
        IERC20(marketParams.collateralToken).safeApprove(address(MORPHO), amount);
        
        // Supply collateral to Morpho
        MORPHO.supplyCollateral(marketParams, amount, address(this), "");
        
        emit CollateralDeposited(marketParams.id(), marketParams.collateralToken, amount);
    }
    
    /// @notice Withdraw collateral from a Morpho market
    /// @param marketParams Market parameters
    /// @param amount Amount of collateral to withdraw
    function withdrawCollateral(
        MarketParams calldata marketParams,
        uint256 amount
    ) external onlyUser {
        // Withdraw collateral from Morpho to user
        MORPHO.withdrawCollateral(marketParams, amount, address(this), msg.sender);
        
        emit CollateralWithdrawn(marketParams.id(), marketParams.collateralToken, amount);
    }
    
    /// @notice Borrow USDC from a Morpho market
    /// @param marketParams Market parameters
    /// @param amount Amount of USDC to borrow
    /// @param toUser If true, send borrowed USDC to user; if false, keep in sub-account
    function borrowUSDC(
        MarketParams calldata marketParams,
        uint256 amount,
        bool toUser
    ) external onlyUser {
        // Borrow USDC from Morpho
        address recipient = toUser ? msg.sender : address(this);
        (uint256 borrowed,) = MORPHO.borrow(marketParams, amount, 0, address(this), recipient);
        
        emit USDCBorrowed(marketParams.id(), borrowed);
    }
    
    /// @notice Repay USDC debt to a Morpho market
    /// @param marketParams Market parameters
    /// @param amount Amount of USDC to repay (use type(uint256).max for full repayment)
    function repayUSDC(
        MarketParams calldata marketParams,
        uint256 amount
    ) external onlyUserOrManager {
        if (amount == type(uint256).max) {
            // Get current debt amount
            Position memory pos = MORPHO.position(marketParams.id(), address(this));
            if (pos.borrowShares == 0) return;
        }
        
        // Transfer USDC from sender to this account
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve Morpho to spend USDC
        IERC20(marketParams.loanToken).safeApprove(address(MORPHO), amount);
        
        // Repay debt
        (uint256 repaidAmount,) = MORPHO.repay(marketParams, amount, 0, address(this), "");
        
        // Refund any excess
        if (amount > repaidAmount) {
            IERC20(marketParams.loanToken).safeTransfer(msg.sender, amount - repaidAmount);
        }
        
        emit USDCRepaid(marketParams.id(), repaidAmount);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // RISEX INTEGRATION
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Deposit USDC to RISEx using the Deposit contract
    /// @param amount Amount of USDC to deposit (in 6 decimals)
    /// @dev Uses the separate Deposit contract which handles scaling and forwarding to PerpsManager
    function depositToRisEx(uint256 amount) external onlyUser {
        // Ensure we have sufficient USDC balance in the sub-account
        require(IERC20(USDC).balanceOf(address(this)) >= amount, "Insufficient USDC balance");
        
        // Scale amount from 6 to 18 decimals (RISEx expects 18 decimals)
        uint256 scaledAmount = amount * 10**12;
        
        // Approve deposit contract to spend USDC
        IERC20(USDC).safeApprove(DEPOSIT_CONTRACT, amount);
        
        // Deposit to RISEx via deposit contract
        IDeposit(DEPOSIT_CONTRACT).deposit(address(this), scaledAmount);
    }
    
    /// @notice Withdraw funds from RISEx
    /// @param token Token to withdraw
    /// @param amount Amount to withdraw
    function withdrawFromRisEx(address token, uint256 amount) external onlyUserOrManager {
        // Withdraw from RISEx to the caller (user or manager during liquidation)
        RISEX.withdraw(msg.sender, token, amount);
    }
    
    /// @notice Place an order on RISEx
    /// @param orderData Encoded order data
    /// @return orderId The order ID
    function placeOrder(bytes calldata orderData) external onlyUser returns (uint256 orderId) {
        return RISEX.placeOrder(orderData);
    }
    
    /// @notice Cancel an order on RISEx
    /// @param cancelData Encoded cancel data
    function cancelOrder(bytes32 cancelData) external onlyUserOrManager {
        RISEX.cancelOrder(cancelData);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // EMERGENCY FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Execute arbitrary call (only manager during liquidation)
    /// @param target Contract to call
    /// @param data Call data
    /// @return success Whether call succeeded
    /// @return returnData Return data from call
    function execute(
        address target,
        bytes calldata data
    ) external onlyManager returns (bool success, bytes memory returnData) {
        (success, returnData) = target.call(data);
        require(success, "Execution failed");
    }
    
    /// @notice Rescue stuck tokens (only manager)
    /// @param token Token to rescue
    /// @param amount Amount to rescue
    /// @param to Recipient
    function rescueToken(
        address token,
        uint256 amount,
        address to
    ) external onlyManager {
        IERC20(token).safeTransfer(to, amount);
    }
}