// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {PortfolioMarginManager} from "../../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../../src/PortfolioSubAccount.sol";
import {IMorpho, MarketParams, Position, Market} from "../../src/interfaces/IMorpho.sol";
import {MarketParamsLib} from "../../src/libraries/morpho/MarketParamsLib.sol";
import {IOracle} from "../../src/interfaces/IOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRISExPerpsManager} from "../../src/interfaces/IRISExPerpsManager.sol";

/// @title EnhancedSetup
/// @notice Comprehensive test setup for portfolio margin system with RISE testnet fork
contract EnhancedSetup is Test {
    // Fork configuration
    string constant RISE_TESTNET_RPC = "https://testnet.riselabs.xyz";
    uint256 forkId;
    bool isForked;
    
    // Core contracts (will be deployed fresh in tests)
    PortfolioMarginManager public manager;
    IMorpho public morpho = IMorpho(0x70374FB7a93fD277E66C525B93f810A7D61d5606);
    IERC20 public usdc = IERC20(0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58);
    IERC20 public weth = IERC20(0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1);
    IERC20 public wbtc = IERC20(0x4ea782275171Be21e3Bf50b2Cdfa84B833349AF1);
    IOracle public wethOracle = IOracle(0xe07eedf78483293348bdcd8F7495d79496F114c0);
    IOracle public wbtcOracle = IOracle(0xdD81dD2FCdCB5BC489a7ea9f694471e540E3492a);
    address constant IRM = 0xBcB3924382eF02C1235521ca63DA3071698Eab90;
    
    // RISEx addresses
    address constant RISEX_PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    IRISExPerpsManager public risex = IRISExPerpsManager(RISEX_PERPS_MANAGER);
    
    // Market IDs
    bytes32 constant WETH_MARKET_ID = 0xde3a900dca2c34338462ed11512f3711290848df5ad86ffe17bae4bfcc63339f;
    bytes32 constant WBTC_MARKET_ID = 0xcc27c517e5d8c04d6139bc94f4a64185d4fd73b33607a27c399864d7641a74bd;
    
    // Market parameters
    MarketParams public wethMarket;
    MarketParams public wbtcMarket;
    
    // Test users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public liquidator = makeAddr("liquidator");
    address public owner;
    
    // Test amounts
    uint256 constant INITIAL_ETH = 10 ether;
    uint256 constant INITIAL_USDC = 100_000e6; // 100k USDC
    uint256 constant INITIAL_WETH = 10e18; // 10 WETH
    uint256 constant INITIAL_WBTC = 2e8; // 2 WBTC
    
    // Common test values
    uint256 constant DEPOSIT_AMOUNT = 5e18; // 5 WETH
    uint256 constant BORROW_AMOUNT = 10_000e6; // 10k USDC
    
    modifier usesFork() {
        if (!isForked) {
            console2.log("Test requires fork mode - skipping");
            return;
        }
        _;
    }
    
    function setUp() public virtual {
        owner = address(this);
        
        // When running with --fork-url, we're already in fork mode
        // Check if we're in a fork by trying to get the fork block
        try vm.activeFork() returns (uint256) {
            isForked = true;
            console2.log("Running on forked network");
        } catch {
            isForked = false;
            console2.log("Running on local network");
        }
        
        // Deploy fresh PortfolioMarginManager with correct RISEx address
        address risexPerpsManager = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
        manager = new PortfolioMarginManager(address(morpho), risexPerpsManager);
        
        // Setup market parameters
        wethMarket = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(weth),
            oracle: address(wethOracle),
            irm: IRM,
            lltv: 0.77e18
        });
        
        wbtcMarket = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(wbtc),
            oracle: address(wbtcOracle),
            irm: IRM,
            lltv: 0.77e18
        });
        
        // Configure markets in the manager
        manager.addMarket(wethMarket, 0.85e18); // 85% collateral factor
        manager.addMarket(wbtcMarket, 0.85e18); // 85% collateral factor
        
        // Setup test balances
        _setupTestBalances();
        
        // Setup labels
        _setupLabels();
    }
    
    function _setupTestBalances() internal {
        // Give users ETH for gas
        vm.deal(alice, INITIAL_ETH);
        vm.deal(bob, INITIAL_ETH);
        vm.deal(charlie, INITIAL_ETH);
        vm.deal(liquidator, INITIAL_ETH);
        
        if (isForked) {
            // On testnet fork, handle each token type appropriately
            _mintUSDC(alice, INITIAL_USDC);
            _mintUSDC(bob, INITIAL_USDC);
            _mintUSDC(liquidator, INITIAL_USDC * 10);
            
            _mintMockTokens(alice, INITIAL_WETH, INITIAL_WBTC);
            _mintMockTokens(bob, INITIAL_WETH, INITIAL_WBTC);
            _mintMockTokens(charlie, INITIAL_WETH, 0); // Charlie only gets WETH
        } else {
            // Local testing - use deal for all tokens
            deal(address(usdc), alice, INITIAL_USDC);
            deal(address(usdc), bob, INITIAL_USDC);
            deal(address(usdc), liquidator, INITIAL_USDC * 10);
            
            deal(address(weth), alice, INITIAL_WETH);
            deal(address(weth), bob, INITIAL_WETH);
            deal(address(weth), charlie, INITIAL_WETH);
            
            deal(address(wbtc), alice, INITIAL_WBTC);
            deal(address(wbtc), bob, INITIAL_WBTC);
        }
    }
    
    function _mintUSDC(address to, uint256 amount) internal {
        // USDC on testnet is a proxy contract
        // Transfer from our funded account instead of trying to mint
        address fundedAccount = 0x8E2f075B24Fd64f3E4d0ccab1ade2646AdA9ABAb;
        
        // Use vm.prank to transfer from funded account
        vm.prank(fundedAccount);
        usdc.transfer(to, amount);
        
        console2.log("Transferred", amount / 1e6, "USDC to", to);
        console2.log("New balance:", usdc.balanceOf(to) / 1e6, "USDC");
    }
    
    function _mintMockTokens(address to, uint256 wethAmount, uint256 wbtcAmount) internal {
        // Our mock tokens should have mint functions that we control
        // First check if they're actually our MockWETH/MockWBTC contracts
        
        // Try to mint WETH
        vm.prank(owner); // Use test contract as owner
        (bool success,) = address(weth).call(
            abi.encodeWithSignature("mint(address,uint256)", to, wethAmount)
        );
        if (!success) {
            // If minting fails, use deal as fallback
            deal(address(weth), to, wethAmount);
        }
        
        // Try to mint WBTC if amount > 0
        if (wbtcAmount > 0) {
            vm.prank(owner);
            (success,) = address(wbtc).call(
                abi.encodeWithSignature("mint(address,uint256)", to, wbtcAmount)
            );
            if (!success) {
                deal(address(wbtc), to, wbtcAmount);
            }
        }
    }
    
    function _setupLabels() internal {
        vm.label(address(manager), "PortfolioMarginManager");
        vm.label(address(morpho), "Morpho");
        vm.label(address(usdc), "USDC");
        vm.label(address(weth), "WETH");
        vm.label(address(wbtc), "WBTC");
        vm.label(address(wethOracle), "WETH Oracle");
        vm.label(address(wbtcOracle), "WBTC Oracle");
        vm.label(IRM, "IRM");
        vm.label(RISEX_PERPS_MANAGER, "RISEx PerpsManager");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(liquidator, "Liquidator");
    }
    
    // Helper functions for common operations
    
    function createOrGetSubAccount(address user) public returns (address subAccount) {
        subAccount = manager.userSubAccounts(user);
        if (subAccount == address(0)) {
            vm.prank(user);
            subAccount = manager.createSubAccount(user);
            console2.log("Created sub-account for", user, "at", subAccount);
        }
        return subAccount;
    }
    
    function depositCollateral(
        address user,
        MarketParams memory market,
        uint256 amount
    ) public returns (address subAccount) {
        subAccount = createOrGetSubAccount(user);
        
        vm.startPrank(user);
        IERC20(market.collateralToken).approve(subAccount, amount);
        PortfolioSubAccount(subAccount).depositCollateral(market, amount);
        vm.stopPrank();
        
        console2.log(user, "deposited", amount / 1e18, "collateral");
    }
    
    function borrowUSDC(
        address user,
        MarketParams memory market,
        uint256 amount
    ) public {
        address subAccount = manager.userSubAccounts(user);
        require(subAccount != address(0), "No sub-account");
        
        vm.prank(user);
        PortfolioSubAccount(subAccount).borrowUSDC(market, amount, true); // Send to user by default
        
        console2.log(user, "borrowed", amount / 1e6, "USDC");
    }
    
    function depositToRisex(address user, uint256 amount) public {
        address subAccount = manager.userSubAccounts(user);
        require(subAccount != address(0), "No sub-account");
        
        vm.prank(user);
        PortfolioSubAccount(subAccount).depositToRisEx(amount);
        
        console2.log(user, "deposited", amount / 1e6, "USDC to RISEx");
    }
    
    function withdrawFromRisex(address user, uint256 amount) public {
        address subAccount = manager.userSubAccounts(user);
        require(subAccount != address(0), "No sub-account");
        
        vm.prank(user);
        PortfolioSubAccount(subAccount).withdrawFromRisEx(address(usdc), amount);
        
        console2.log(user, "withdrew", amount / 1e6, "USDC from RISEx");
    }
    
    function getHealth(address user) public view returns (
        uint256 totalCollateralValue,
        uint256 totalDebtValue,
        int256 risexEquity,
        uint256 healthFactor,
        bool isHealthy
    ) {
        PortfolioMarginManager.HealthStatus memory health = manager.getPortfolioHealth(user);
        return (
            health.totalCollateralValue,
            health.totalDebtValue,
            health.risexEquity,
            health.healthFactor,
            health.isHealthy
        );
    }
    
    function logHealth(address user) public view {
        (
            uint256 collateralValue,
            uint256 debtValue,
            int256 risexEquity,
            uint256 healthFactor,
            bool isHealthy
        ) = getHealth(user);
        
        console2.log("=== Health Status for", user, "===");
        console2.log("Collateral Value: $", collateralValue / 1e6);
        console2.log("Debt Value: $", debtValue / 1e6);
        console2.log("RISEx Equity: $", uint256(risexEquity) / 1e6);
        console2.log("Health Factor:", healthFactor * 100 / 1e18, "%");
        console2.log("Is Healthy:", isHealthy);
    }
    
    function getMorphoPosition(address subAccount, MarketParams memory market) public view returns (Position memory) {
        // Use the MarketParamsLib to calculate market ID
        bytes32 marketId = MarketParamsLib.id(market);
        return morpho.position(marketId, subAccount);
    }
    
    // Note: These functions would work if RISEx interface was properly defined
    // For now, commenting out to allow compilation
    
    // function getRisexBalance(address subAccount, address token) public view returns (int256) {
    //     return risex.getBalance(subAccount, token);
    // }
    
    // function getRisexEquity(address subAccount) public view returns (int256) {
    //     return risex.getAccountEquity(subAccount);
    // }
    
    // Price manipulation helpers for testing
    
    function setWETHPrice(uint256 newPrice) public {
        // Note: This only works with mock oracles that have setPrice function
        // For real oracles, would need different approach
        vm.mockCall(
            address(wethOracle),
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(newPrice)
        );
    }
    
    function setWBTCPrice(uint256 newPrice) public {
        vm.mockCall(
            address(wbtcOracle),
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(newPrice)
        );
    }
    
    // Time manipulation
    
    function skipTime(uint256 seconds_) public {
        skip(seconds_);
        // Accrue interest on Morpho markets
        morpho.accrueInterest(wethMarket);
        morpho.accrueInterest(wbtcMarket);
    }
    
    // Assertion helpers
    
    function assertHealthy(address user) public {
        assertTrue(manager.isHealthy(user), "Portfolio should be healthy");
    }
    
    function assertUnhealthy(address user) public {
        assertFalse(manager.isHealthy(user), "Portfolio should be unhealthy");
    }
    
    function assertApproxEqRelative(
        uint256 a,
        uint256 b,
        uint256 maxRelDelta,
        string memory err
    ) internal pure {
        if (b == 0) {
            assertEq(a, b, err);
            return;
        }
        
        uint256 delta = a > b ? a - b : b - a;
        uint256 relDelta = (delta * 1e18) / b;
        
        if (relDelta > maxRelDelta) {
            revert(string.concat(err, " (delta too high)"));
        }
    }
}