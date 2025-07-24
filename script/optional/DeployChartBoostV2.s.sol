// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {ChartBoostV2} from "../../src/optional/ChartBoostV2.sol";

contract DeployChartBoostV2 is Script {
    ChartBoostV2 public chartBoostV2;

    function run() public {
        vm.startBroadcast();

        chartBoostV2 = new ChartBoostV2{salt: keccak256("ChartBoostV2")}();

        vm.stopBroadcast();
    }
}
