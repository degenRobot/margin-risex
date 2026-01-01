// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {PortfolioMarginManager} from "../src/PortfolioMarginManager.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";

/// @title Update Portfolio Margin with RISEx
/// @notice Redeploy PortfolioMarginManager with correct RISEx address
contract UpdatePortfolioMarginWithRISEx is Script {
    // RISE testnet deployed contracts
    address constant MORPHO = 0x70374FB7a93fD277E66C525B93f810A7D61d5606;
    address constant RISEX_PERPS_MANAGER = 0x68cAcD54a8c93A3186BF50bE6b78B761F728E1b4;
    
    // Old manager (with wrong RISEx)
    address constant OLD_MANAGER = 0xB13Ec61327b78A024b344409D31f3e3F25eC2499;
    
    // Market configuration
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    address constant WBTC = 0x4ea782275171Be21e3Bf50b2Cdfa84B833349AF1;
    address constant WETH_ORACLE = 0xe07eedf78483293348bdcd8F7495d79496F114c0;
    address constant WBTC_ORACLE = 0xdD81dD2FCdCB5BC489a7ea9f694471e540E3492a;
    address constant IRM = 0xBcB3924382eF02C1235521ca63DA3071698Eab90;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        require(deployerPrivateKey != 0, "PRIVATE_KEY not set");
        
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deploying from:", deployer);
        console2.log("Old manager:", OLD_MANAGER);
        console2.log("Correct RISEx address:", RISEX_PERPS_MANAGER);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new PortfolioMarginManager with correct RISEx address
        PortfolioMarginManager newManager = new PortfolioMarginManager(
            MORPHO,
            RISEX_PERPS_MANAGER
        );
        
        console2.log("New PortfolioMarginManager deployed at:", address(newManager));
        
        // Add the same markets as before
        console2.log("\nAdding markets...");
        
        // WETH -> USDC market
        MarketParams memory wethMarket = MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: WETH_ORACLE,
            irm: IRM,
            lltv: 0.77e18
        });
        newManager.addMarket(wethMarket, 0.85e18); // 85% collateral factor
        console2.log("Added WETH market");
        
        // WBTC -> USDC market
        MarketParams memory wbtcMarket = MarketParams({
            loanToken: USDC,
            collateralToken: WBTC,
            oracle: WBTC_ORACLE,
            irm: IRM,
            lltv: 0.77e18
        });
        newManager.addMarket(wbtcMarket, 0.85e18); // 85% collateral factor
        console2.log("Added WBTC market");
        
        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Summary ===");
        console2.log("New PortfolioMarginManager:", address(newManager));
        console2.log("SubAccount Implementation:", newManager.SUB_ACCOUNT_IMPL());
        console2.log("Markets configured: 2 (WETH, WBTC)");
        console2.log("\nIMPORTANT: Update all references from old manager to new manager!");
        
        // Write deployment info to file
        string memory deploymentInfo = string.concat(
            "New PortfolioMarginManager=", vm.toString(address(newManager)), "\n",
            "SubAccount Implementation=", vm.toString(newManager.SUB_ACCOUNT_IMPL()), "\n",
            "Timestamp=", vm.toString(block.timestamp), "\n"
        );
        
        vm.writeFile("./deployments/portfolio-margin-updated.txt", deploymentInfo);
    }
}