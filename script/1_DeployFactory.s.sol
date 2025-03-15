// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TidalDexFactory} from "../src/TidalDexFactory.sol";

contract DeployFactoryScript is Script {
    TidalDexFactory public tidalDexFactory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        tidalDexFactory = new TidalDexFactory();

        vm.stopBroadcast();
    }
}
