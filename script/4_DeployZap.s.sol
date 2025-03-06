// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AmmZapV1} from "../src/amm/AmmZapV1.sol";

contract DeployZapScript is Script {
    AmmZapV1 public ammZapV1;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        ammZapV1 = new AmmZapV1(
            //WETH
            address(
                //0x0
                //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c //56 (BNB MAINNET)
                0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd //97 (BNB TESTNET)
            ),
            // Router
            address(
                // 0x0
                0x71aB950a0C349103967e711b931c460E9580c631 //56, 97 (BNB MAINNET & TESTNET)
            ),
            // Owner
            address(0x745A676C5c472b50B50e18D4b59e9AeEEc597046), //CZodiac Multisig
            // Max zap reverse ratio, e.g. 500 = 5%, prevents excessive price impact
            50
        );

        vm.stopBroadcast();
    }
}
