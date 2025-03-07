// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
// Credit to Yearn
pragma solidity ^0.8.4;

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function withdraw(uint256) external;
}
