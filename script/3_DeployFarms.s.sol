// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {TidalDexFarmMaster} from "../src/TidalDexFarmMaster.sol";
import {IERC20MintableBurnable} from "../src/interfaces/IERC20MintableBurnable.sol";

contract DeployTidalDexFarmMasterScript is Script {
    TidalDexFarmMaster public tidalDexFarmMaster;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        tidalDexFarmMaster = new TidalDexFarmMaster(
            //uint256 _startTimestamp
            0,
            //IERC20MintableBurnable _ytkn
            IERC20MintableBurnable(address(0xD963b2236D227a0302E19F2f9595F424950dc186)),
            //address _treasury
            address(0x745A676C5c472b50B50e18D4b59e9AeEEc597046)
        );

        vm.stopBroadcast();
    }
}
