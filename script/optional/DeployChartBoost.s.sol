// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {ChartBoost} from "../../src/optional/ChartBoost.sol";

contract DeployChartBoost is Script {
    ChartBoost public chartBoost;

    function run() public {
        vm.startBroadcast();

        chartBoost = new ChartBoost{salt: keccak256("ChartBoost")}();

        vm.stopBroadcast();
    }
}
