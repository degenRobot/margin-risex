// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseDeployment} from "./BaseDeployment.s.sol";
import {MockWETH} from "../src/mocks/MockWETH.sol";
import {MockWBTC} from "../src/mocks/MockWBTC.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockOracle} from "../src/mocks/MockOracle.sol";
import {MockIRM} from "../src/mocks/MockIRM.sol";
import {console2} from "forge-std/console2.sol";

/// @title DeployMocks
/// @notice Deploy mock tokens, oracles, and IRM for testing
contract DeployMocks is BaseDeployment {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Deploying Mock Contracts ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("");
        
        // Load existing deployment if it exists
        loadDeployment();
        deployment.deployer = deployer;
        deployment.chainId = block.chainid;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Mock Tokens
        if (deployment.weth == address(0)) {
            deployment.weth = address(new MockWETH());
            console2.log("MockWETH deployed at:", deployment.weth);
        } else {
            console2.log("MockWETH already deployed at:", deployment.weth);
        }
        
        if (deployment.wbtc == address(0)) {
            deployment.wbtc = address(new MockWBTC());
            console2.log("MockWBTC deployed at:", deployment.wbtc);
        } else {
            console2.log("MockWBTC already deployed at:", deployment.wbtc);
        }
        
        // Deploy Mock USDC
        if (deployment.usdc == address(0)) {
            deployment.usdc = address(new MockUSDC());
            console2.log("MockUSDC deployed at:", deployment.usdc);
        } else {
            console2.log("MockUSDC already deployed at:", deployment.usdc);
        }
        
        // Deploy Oracles
        // WETH/USDC price: $3000 per ETH
        // Price calculation: 3000 * 10^(36 + 6 - 18) = 3000 * 10^24
        if (deployment.wethOracle == address(0)) {
            uint256 wethPrice = 3000 * 10**24;
            deployment.wethOracle = address(new MockOracle(wethPrice));
            console2.log("WETH Oracle deployed at:", deployment.wethOracle);
            console2.log("  Initial price: $3000/ETH");
        } else {
            console2.log("WETH Oracle already deployed at:", deployment.wethOracle);
        }
        
        // WBTC/USDC price: $50000 per BTC  
        // Price calculation: 50000 * 10^(36 + 6 - 8) = 50000 * 10^34
        if (deployment.wbtcOracle == address(0)) {
            uint256 wbtcPrice = 50000 * 10**34;
            deployment.wbtcOracle = address(new MockOracle(wbtcPrice));
            console2.log("WBTC Oracle deployed at:", deployment.wbtcOracle);
            console2.log("  Initial price: $50000/BTC");
        } else {
            console2.log("WBTC Oracle already deployed at:", deployment.wbtcOracle);
        }
        
        // Deploy IRM with 5% APR
        if (deployment.irm == address(0)) {
            uint256 fivePercentAPR = 0.05e18;
            deployment.irm = address(new MockIRM(fivePercentAPR));
            console2.log("Mock IRM deployed at:", deployment.irm);
            console2.log("  Initial rate: 5% APR");
        } else {
            console2.log("Mock IRM already deployed at:", deployment.irm);
        }
        
        vm.stopBroadcast();
        
        // Save deployment addresses
        saveDeployment();
        
        console2.log("");
        console2.log("=== Mock Deployment Complete ===");
        console2.log("Deployment data saved to deployments/", block.chainid, ".json");
    }
}