// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {PortfolioMarginManager} from "../../src/PortfolioMarginManager.sol";
import {PortfolioSubAccount} from "../../src/PortfolioSubAccount.sol";
import {IMorpho, MarketParams, Id} from "morpho-blue/interfaces/IMorpho.sol";
import {IOracle} from "morpho-blue/interfaces/IOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockWETH} from "../../src/mocks/MockWETH.sol";
import {MockWBTC} from "../../src/mocks/MockWBTC.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockOracle} from "../../src/mocks/MockOracle.sol";
import {MockIRM} from "../../src/mocks/MockIRM.sol";

contract Setup is Test {
    // Fork URL
    string constant RISE_TESTNET_RPC = "https://testnet.riselabs.xyz";
    uint256 forkId;
    
    // Core contracts
    PortfolioMarginManager public manager;
    PortfolioSubAccount public subAccountImpl;
    IMorpho public morpho;
    
    // Mock tokens (when not forking)
    MockWETH public weth;
    MockWBTC public wbtc;
    MockUSDC public usdc;
    MockOracle public wethOracle;
    MockOracle public wbtcOracle;
    MockIRM public irm;
    
    // Deployed addresses from testnet
    address payable constant DEPLOYED_MORPHO = payable(0x70374FB7a93fD277E66C525B93f810A7D61d5606);
    address payable constant DEPLOYED_PORTFOLIO_MANAGER = payable(0xB13Ec61327b78A024b344409D31f3e3F25eC2499);
    address payable constant DEPLOYED_USDC = payable(0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58);
    address payable constant DEPLOYED_WETH = payable(0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1);
    address payable constant DEPLOYED_WBTC = payable(0x4ea782275171Be21e3Bf50b2Cdfa84B833349AF1);
    address payable constant DEPLOYED_WETH_ORACLE = payable(0xe07eedf78483293348bdcd8F7495d79496F114c0);
    address payable constant DEPLOYED_WBTC_ORACLE = payable(0xdD81dD2FCdCB5BC489a7ea9f694471e540E3492a);
    address payable constant DEPLOYED_IRM = payable(0xBcB3924382eF02C1235521ca63DA3071698Eab90);
    
    // Market IDs
    bytes32 constant WETH_MARKET_ID = 0xde3a900dca2c34338462ed11512f3711290848df5ad86ffe17bae4bfcc63339f;
    bytes32 constant WBTC_MARKET_ID = 0xcc27c517e5d8c04d6139bc94f4a64185d4fd73b33607a27c399864d7641a74bd;
    
    // RISEx addresses
    address constant RISEX_PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    address constant RISEX_AUTH = 0x8d8708f9D87ef522c1f99DD579BF6A051e34C28E;
    address constant RISEX_ORACLE = 0x0C7Be7DfAbBA609A5A215a716aDc4dF089EC3952;
    
    // Test addresses
    address public owner;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public liquidator = makeAddr("liquidator");
    
    // Test parameters
    uint256 constant INITIAL_BALANCE = 1_000_000e6; // 1M USDC
    uint256 constant INITIAL_WETH = 100e18; // 100 WETH
    uint256 constant INITIAL_WBTC = 10e8; // 10 WBTC
    
    // Market parameters
    MarketParams public wethMarketParams;
    MarketParams public wbtcMarketParams;
    
    function setUp() public virtual {
        owner = address(this);
        
        // Check if we should fork
        bool shouldFork = false;
        try vm.envBool("FORK_RISE_TESTNET") returns (bool fork) {
            shouldFork = fork;
        } catch {}
        
        if (shouldFork) {
            // Fork RISE testnet
            forkId = vm.createFork(RISE_TESTNET_RPC);
            vm.selectFork(forkId);
            console2.log("Forked RISE testnet at block:", block.number);
            
            // Use deployed contracts
            manager = PortfolioMarginManager(DEPLOYED_PORTFOLIO_MANAGER);
            morpho = IMorpho(DEPLOYED_MORPHO);
            usdc = MockUSDC(DEPLOYED_USDC);
            weth = MockWETH(DEPLOYED_WETH);
            wbtc = MockWBTC(DEPLOYED_WBTC);
            wethOracle = MockOracle(DEPLOYED_WETH_ORACLE);
            wbtcOracle = MockOracle(DEPLOYED_WBTC_ORACLE);
            irm = MockIRM(DEPLOYED_IRM);
        } else {
            // Deploy fresh mocks for local testing
            _deployMocks();
            _deployMorpho();
            _deployPortfolioSystem();
        }
        
        // Setup market parameters
        _setupMarketParams();
        
        // Setup test balances
        _setupTestBalances();
        
        // Setup labels
        _setupLabels();
    }
    
    function _deployMocks() internal {
        // Deploy mock tokens
        weth = new MockWETH();
        wbtc = new MockWBTC();
        usdc = new MockUSDC();
        
        // Deploy oracles with realistic prices
        wethOracle = new MockOracle(3000 * 10**24); // $3000/ETH
        wbtcOracle = new MockOracle(50000 * 10**34); // $50000/BTC
        
        // Deploy IRM with 5% APR
        irm = new MockIRM(0.05e18);
        
        console2.log("Deployed mocks locally");
    }
    
    function _deployMorpho() internal {
        // Import Morpho deployment logic from our scripts
        // For now, we'll assume Morpho is already deployed on testnet
        revert("Local Morpho deployment not implemented - use fork mode");
    }
    
    function _deployPortfolioSystem() internal {
        // Deploy portfolio margin system
        manager = new PortfolioMarginManager(
            address(morpho),
            RISEX_PERPS_MANAGER
        );
        
        // Add markets to manager
        vm.startPrank(owner);
        manager.addMarket(wethMarketParams, 0.85e18); // 85% collateral factor
        manager.addMarket(wbtcMarketParams, 0.85e18); // 85% collateral factor
        vm.stopPrank();
    }
    
    function _setupMarketParams() internal {
        wethMarketParams = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(weth),
            oracle: address(wethOracle),
            irm: address(irm),
            lltv: 0.77e18 // 77% LLTV
        });
        
        wbtcMarketParams = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(wbtc),
            oracle: address(wbtcOracle),
            irm: address(irm),
            lltv: 0.77e18 // 77% LLTV
        });
    }
    
    function _setupTestBalances() internal {
        // Deal tokens to test users
        deal(address(usdc), alice, INITIAL_BALANCE);
        deal(address(usdc), bob, INITIAL_BALANCE);
        deal(address(usdc), liquidator, INITIAL_BALANCE);
        
        deal(address(weth), alice, INITIAL_WETH);
        deal(address(weth), bob, INITIAL_WETH);
        
        deal(address(wbtc), alice, INITIAL_WBTC);
        deal(address(wbtc), bob, INITIAL_WBTC);
        
        // Deal ETH for gas
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(liquidator, 100 ether);
    }
    
    function _setupLabels() internal {
        vm.label(address(manager), "PortfolioMarginManager");
        vm.label(address(morpho), "Morpho");
        vm.label(address(usdc), "USDC");
        vm.label(address(weth), "WETH");
        vm.label(address(wbtc), "WBTC");
        vm.label(address(wethOracle), "WETH Oracle");
        vm.label(address(wbtcOracle), "WBTC Oracle");
        vm.label(address(irm), "IRM");
        vm.label(RISEX_PERPS_MANAGER, "RISEx PerpsManager");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(liquidator, "Liquidator");
    }
    
    // Helper functions
    
    /// @notice Create and initialize a sub-account for a user
    function createSubAccount(address user) public returns (address subAccount) {
        subAccount = manager.createSubAccount(user);
        console2.log("Created sub-account for", user, "at", subAccount);
    }
    
    /// @notice Deposit collateral to Morpho through sub-account
    function depositCollateral(
        address user,
        address subAccount,
        MarketParams memory marketParams,
        uint256 amount
    ) public {
        vm.startPrank(user);
        
        // Approve sub-account to spend collateral
        IERC20(marketParams.collateralToken).approve(subAccount, amount);
        
        // Deposit through sub-account
        PortfolioSubAccount(subAccount).depositCollateral(marketParams, amount);
        
        vm.stopPrank();
    }
    
    /// @notice Borrow USDC through sub-account
    function borrowUSDC(
        address user,
        address subAccount,
        MarketParams memory marketParams,
        uint256 amount
    ) public {
        vm.prank(user);
        PortfolioSubAccount(subAccount).borrowUSDC(marketParams, amount);
    }
    
    /// @notice Get portfolio health status
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
    
    /// @notice Assert that a portfolio is healthy
    function assertHealthy(address user) public {
        assertTrue(manager.isHealthy(user), "Portfolio should be healthy");
    }
    
    /// @notice Assert that a portfolio is unhealthy
    function assertUnhealthy(address user) public {
        assertFalse(manager.isHealthy(user), "Portfolio should be unhealthy");
    }
    
    /// @notice Skip time and accrue interest
    function skipTime(uint256 seconds_) public {
        skip(seconds_);
        
        // Accrue interest on Morpho markets
        morpho.accrueInterest(wethMarketParams);
        morpho.accrueInterest(wbtcMarketParams);
    }
    
    /// @notice Manipulate oracle price for testing
    function setOraclePrice(address oracle, uint256 newPrice) public {
        vm.prank(MockOracle(oracle).owner());
        MockOracle(oracle).setPrice(newPrice);
    }
    
    /// @notice Calculate expected liquidation incentive
    function calculateLiquidationIncentive(uint256 collateralAmount) public pure returns (uint256) {
        return (collateralAmount * 0.05e18) / 1e18; // 5% incentive
    }
}