// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorpho, MarketParams} from "../src/interfaces/IMorpho.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}

contract QuickMorphoSetup is Script {
    address constant USDC = 0x8d17fC7Db6b4FCf40AFB296354883DEC95a12f58;
    address constant WETH = 0x2B810002D2d6393E8E6B321a6B8cCF2F2E7726e1;
    address constant MORPHO = 0x70374FB7a93fD277E66C525B93f810A7D61d5606;
    
    // WETH Market params
    address constant WETH_ORACLE = 0xe07eedf78483293348bdcd8F7495d79496F114c0;
    address constant IRM = 0xBcB3924382eF02C1235521ca63DA3071698Eab90;
    uint256 constant LLTV = 770000000000000000; // 77%
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=== Quick Morpho Setup ===");
        console2.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Mint some USDC to deployer
        console2.log("\n1. Minting 100k USDC...");
        IMintable(USDC).mint(deployer, 100_000e6);
        
        // 2. Approve Morpho
        console2.log("2. Approving Morpho...");
        IERC20(USDC).approve(MORPHO, 100_000e6);
        
        // 3. Create market params
        MarketParams memory marketParams = MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: WETH_ORACLE,
            irm: IRM,
            lltv: LLTV
        });
        
        // 4. Supply USDC to Morpho
        console2.log("3. Supplying 100k USDC to Morpho WETH market...");
        (uint256 supplied, uint256 shares) = IMorpho(MORPHO).supply(
            marketParams,
            100_000e6,
            0,
            deployer,
            ""
        );
        
        console2.log("   - Supplied:", supplied / 1e6, "USDC");
        console2.log("   - Received shares:", shares);
        
        vm.stopBroadcast();
        
        console2.log("\n=== Morpho Setup Complete ===");
        console2.log("You can now borrow USDC against WETH collateral!");
    }
}