// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Constants
/// @notice Central repository for all contract addresses and constants
library Constants {
    // ============ RISE Testnet Addresses ============
    
    // Core Contracts
    address internal constant PORTFOLIO_MARGIN_MANAGER = 0xB13Ec61327b78A024b344409D31f3e3F25eC2499; // To be updated
    address internal constant MORPHO = 0x70374FB7a93fD277E66C525B93f810A7D61d5606;
    
    // RISEx Contracts
    address internal constant RISEX_PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    address internal constant RISEX_WHITELIST = 0x5b2Fcc7C1efC8f8D9968a5de2F51063984db41E5;
    address internal constant RISEX_AUTH = 0x8d8708f9D87ef522c1f99DD579BF6A051e34C28E;
    address internal constant RISEX_DEPOSIT = 0x5BC20A936EfEE0d758A3c168d2f017c83805B986;
    address internal constant RISEX_ORACLE = 0x0C7Be7DfAbBA609A5A215a716aDc4dF089EC3952;
    address internal constant RISEX_FEE_MANAGER = 0xC96dF9c9CDc9A03A5c69BF291035f8299145c6EC;
    
    // Tokens
    address internal constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address internal constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    address internal constant WBTC = 0x4ea782275171Be21e3Bf50b2Cdfa84B833349AF1;
    
    // Oracles
    address internal constant WETH_ORACLE = 0xe07eedf78483293348bdcd8F7495d79496F114c0;
    address internal constant WBTC_ORACLE = 0xdD81dD2FCdCB5BC489a7ea9f694471e540E3492a;
    
    // Interest Rate Model
    address internal constant IRM = 0xBcB3924382eF02C1235521ca63DA3071698Eab90;
    
    // Multicall
    address internal constant MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    
    // ============ Market IDs ============
    
    // Morpho Market IDs
    bytes32 internal constant WETH_MARKET_ID = 0xde3a900dca2c34338462ed11512f3711290848df5ad86ffe17bae4bfcc63339f;
    bytes32 internal constant WBTC_MARKET_ID = 0xcc27c517e5d8c04d6139bc94f4a64185d4fd73b33607a27c399864d7641a74bd;
    
    // RISEx Market IDs
    uint256 internal constant RISEX_BTC_MARKET = 1;
    uint256 internal constant RISEX_ETH_MARKET = 2;
    
    // ============ Risk Parameters ============
    
    // Liquidation Parameters
    uint256 internal constant LIQUIDATION_THRESHOLD = 0.95e18; // 95%
    uint256 internal constant MIN_HEALTH_FOR_ACTIONS = 1.05e18; // 105%
    uint256 internal constant LIQUIDATION_INCENTIVE = 0.05e18; // 5%
    
    // Market Parameters
    uint256 internal constant MORPHO_LLTV = 0.77e18; // 77%
    uint256 internal constant COLLATERAL_FACTOR = 0.85e18; // 85%
    
    // ============ Test Addresses ============
    
    // Test Accounts (for testing only)
    address internal constant TEST_DEPLOYER = 0x8E2f075B24Fd64f3E4d0ccab1ade2646AdA9ABAb;
    
    // ============ Token Decimals ============
    
    uint8 internal constant USDC_DECIMALS = 6;
    uint8 internal constant WETH_DECIMALS = 18;
    uint8 internal constant WBTC_DECIMALS = 8;
    
    // ============ Time Constants ============
    
    uint256 internal constant ONE_DAY = 86400;
    uint256 internal constant ONE_WEEK = 604800;
    uint256 internal constant ONE_YEAR = 31536000;
}