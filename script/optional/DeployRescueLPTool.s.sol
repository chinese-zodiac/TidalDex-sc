// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {RescueTokenFromLPViaMintTool} from "../../src/RescueLPTool.sol";

contract DeployRescueLPTool is Script {
    RescueTokenFromLPViaMintTool public rescueLPTool;

    function run() public {
        vm.startBroadcast();

        rescueLPTool = new RescueTokenFromLPViaMintTool(
            address(0xfcD9F2d36f7315d2785BA19ca920B14116EA3451)
        );

        vm.stopBroadcast();
    }
}
