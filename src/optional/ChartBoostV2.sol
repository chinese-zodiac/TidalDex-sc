// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {TidalDexRouter} from "../TidalDexRouter.sol";
import {TidalDexFactory} from "../TidalDexFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Mintable} from "../interfaces/IERC20Mintable.sol";
import {IERC20Burnable} from "../interfaces/IERC20Burnable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IAmmPair} from "../interfaces/IAmmPair.sol";

/// @title ChartBoost
/// @notice Requires 500 CZUSD in LP and 2M CZB in LP.
/// @notice A contract that allows users to boost their token on TidalDex.com
/// @dev Transfer tax tokens will revert.
contract ChartBoostV2 is ReentrancyGuard {
    address private constant czusd = 0xE68b79e51bf826534Ff37AA9CeE71a3842ee9c70;
    address private constant czb = 0xD963b2236D227a0302E19F2f9595F424950dc186;

    TidalDexFactory private constant factory =
        TidalDexFactory(0x907e8C7D471877b4742dA8aA53d257d0d565A47E);

    TidalDexRouter private constant router =
        TidalDexRouter(payable(0x71aB950a0C349103967e711b931c460E9580c631));

    constructor() {
        IERC20(czb).approve(address(router), type(uint256).max);
        IERC20(czusd).approve(address(router), type(uint256).max);
    }

    /// @notice Must have both CZB and CZUSD liquidity on TidalDex.com for the token to be traded.
    function run(address token) external nonReentrant {
        // 0. Setup and checks
        address tokenCzusdLpToken = factory.getPair(token, czusd);
        address tokenCzbLpToken = factory.getPair(token, czb);

        // Balances of the lp token addresses.
        uint256 lpCzusdBalInitial = IERC20(czusd).balanceOf(
            address(tokenCzusdLpToken)
        );
        uint256 lpCzbBalInitial = IERC20(czb).balanceOf(
            address(tokenCzbLpToken)
        );
        uint256 tokenBalCzusdLpInitial = IERC20(token).balanceOf(
            tokenCzusdLpToken
        );
        uint256 tokenBalCzbLpInitial = IERC20(token).balanceOf(tokenCzbLpToken);

        uint256 czusdInitialTotalSupply = IERC20(czusd).totalSupply();
        uint256 czbInitialTotalSupply = IERC20(czb).totalSupply();

        require(lpCzusdBalInitial > 500 ether, "Insufficient CZUSD liquidity");
        require(
            lpCzbBalInitial > 2_000_000 ether,
            "Insufficient CZB liquidity"
        );

        // if this contract has any czb, czusd burn them
        if (IERC20(czb).balanceOf(address(this)) > 0)
            IERC20Burnable(czb).burn(IERC20(czb).balanceOf(address(this)));
        if (IERC20(czusd).balanceOf(address(this)) > 0)
            IERC20Burnable(czusd).burn(IERC20(czusd).balanceOf(address(this)));
        // if this contract has any tokens, transfer them to the caller
        if (IERC20(token).balanceOf(address(this)) > 0)
            IERC20(token).transfer(
                msg.sender,
                IERC20(token).balanceOf(address(this))
            );

        uint256 targetCzusdAmt = lpCzusdBalInitial / _pseudoRand(40, 80);

        address[] memory pGetCzbOut = new address[](2);
        pGetCzbOut[0] = czusd;
        pGetCzbOut[1] = czb;

        uint256 czbAmt = router.getAmountsOut(targetCzusdAmt, pGetCzbOut)[1];

        // 1. Swap.
        address[] memory fullPath = new address[](3);
        fullPath[0] = czb;
        fullPath[1] = token;
        fullPath[2] = czusd;
        IERC20Mintable(czb).mint(address(this), czbAmt);

        address[] memory partialPath = new address[](2);
        partialPath[0] = czusd;
        partialPath[1] = token;

        // Full trade, 100%
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            czbAmt,
            0,
            fullPath,
            address(this),
            block.timestamp
        );

        // Partial trade
        // Because of CZB fees, we have to buy with a bit extra czusd.
        // Split in two parts, 50/50.
        IERC20Mintable(czusd).mint(
            address(this),
            IERC20(czusd).balanceOf(address(this)) / 200
        );
        uint256 czusdAmt = IERC20(czusd).balanceOf(address(this));
        uint256 czusdAmtHalf = czusdAmt / 2;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            czusdAmtHalf,
            0,
            partialPath,
            address(this),
            block.timestamp
        );
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            czusdAmt - czusdAmtHalf,
            0,
            partialPath,
            address(this),
            block.timestamp
        );

        // 2. Rebalance.
        // CZUSD does not require rebalance - all the czusd that was removed was put back.

        // Token will be lower than initial for the czb pool, and it will be in this contract.
        IERC20(token).transfer(
            tokenCzbLpToken,
            tokenBalCzbLpInitial - IERC20(token).balanceOf(tokenCzbLpToken)
        );

        // Because we mint extra czusd, there will be a bit extra tokens neede for the czusd lp.
        IERC20(token).transfer(
            tokenCzusdLpToken,
            IERC20(token).balanceOf(address(this))
        );

        // Balance of this contract will be 0 for the token now.
        require(
            IERC20(token).balanceOf(address(this)) == 0,
            "Token balance of this contract is not 0"
        );

        // CZB rebalance, it will be too high due to minting czb.
        IERC20Burnable(czb).burnFrom(
            tokenCzbLpToken,
            IERC20(czb).balanceOf(tokenCzbLpToken) - lpCzbBalInitial
        );

        // CZUSD rebalance, it will be too high due to minting czusd.
        IERC20Burnable(czusd).burnFrom(
            tokenCzusdLpToken,
            IERC20(czusd).balanceOf(tokenCzusdLpToken) - lpCzusdBalInitial
        );

        // 3. Sync.
        IAmmPair(tokenCzusdLpToken).sync();
        IAmmPair(tokenCzbLpToken).sync();

        // 4. Confirm the total supply of CZUSD and CZB, lp balance, and token balance are the same as initially.

        if (IERC20(czusd).balanceOf(address(this)) > 0)
            IERC20Burnable(czusd).burn(IERC20(czusd).balanceOf(address(this)));
        if (IERC20(czb).balanceOf(address(this)) > 0)
            IERC20Burnable(czb).burn(IERC20(czb).balanceOf(address(this)));

        require(
            czusdInitialTotalSupply == IERC20(czusd).totalSupply(),
            "CZUSD total supply has changed"
        );
        require(
            czbInitialTotalSupply == IERC20(czb).totalSupply(),
            "CZB total supply has changed"
        );
        require(
            IERC20(token).balanceOf(tokenCzusdLpToken) ==
                tokenBalCzusdLpInitial,
            "Token balance of CZUSD pool is not the same as initially"
        );
        require(
            IERC20(token).balanceOf(tokenCzbLpToken) == tokenBalCzbLpInitial,
            "Token balance of CZB pool is not the same as initially"
        );
        require(
            IERC20(czusd).balanceOf(tokenCzusdLpToken) == lpCzusdBalInitial,
            "CZUSD balance of CZUSD pool is not the same as initially"
        );
        require(
            IERC20(czb).balanceOf(tokenCzbLpToken) == lpCzbBalInitial,
            "CZB balance of CZB pool is not the same as initially"
        );
    }

    /// @notice Pseudo-random number generator using block hash
    function _pseudoRand(
        uint256 min,
        uint256 max
    ) internal view returns (uint256) {
        return (uint256(blockhash(block.number - 1)) % (max - min + 1)) + min;
    }
}
