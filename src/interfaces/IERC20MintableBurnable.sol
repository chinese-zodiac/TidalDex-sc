// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.19;

import {IERC20Mintable} from "./IERC20Mintable.sol";

interface IERC20MintableBurnable is IERC20Mintable {
    function burn(uint256 value) external;
    function burnFrom(address account, uint256 value) external;
}
