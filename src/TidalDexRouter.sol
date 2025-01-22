// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {AmmRouter} from "./amm/AmmRouter02.sol";

contract TidalDexRouter is AmmRouter {
    constructor(
        address _WETH
    )
        AmmRouter(
            address(0x907e8C7D471877b4742dA8aA53d257d0d565A47E), //factory
            _WETH
        )
    {}
}
