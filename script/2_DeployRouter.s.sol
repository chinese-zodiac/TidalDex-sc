// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TidalDexRouter} from "../src/TidalDexRouter.sol";

contract DeployRouterScript is Script {
    TidalDexRouter public tidalDexRouter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        tidalDexRouter = new TidalDexRouter(
            //WETH
            address(
                0x0
                //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c //56 (BNB MAINNET)
                //0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd //97 (BNB TESTNET)
            )
        );

        vm.stopBroadcast();
    }
}
