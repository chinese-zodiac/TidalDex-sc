// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {TokenBurningAndLP} from "../../src/optional/TokenBurningAndLP.sol";
import {IERC20Burnable} from "../../src/interfaces/IERC20Burnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAmmRouter02} from "../../src/interfaces/IAmmRouter02.sol";

contract DeployTokenBurningAndLP is Script {
    TokenBurningAndLP public tokenBurningAndLP;

    function run() public {
        vm.startBroadcast();

        // Deploy the TokenBurningAndLP contract
        tokenBurningAndLP = new TokenBurningAndLP(
            address(0xfcD9F2d36f7315d2785BA19ca920B14116EA3451),
            IERC20Burnable(address(0x8F452a1fdd388A45e1080992eFF051b4dd9048d2)), //subjectToken,
            IERC20(address(0xE68b79e51bf826534Ff37AA9CeE71a3842ee9c70)), //baseToken,
            IERC20(address(0xD963b2236D227a0302E19F2f9595F424950dc186)), //intermediateToken,
            IAmmRouter02(address(0x71aB950a0C349103967e711b931c460E9580c631)), //router,
            5_000 //liquidityRatio 50%
        );

        vm.stopBroadcast();
    }
}
