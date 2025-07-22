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
contract ChartBoost is ReentrancyGuard {
    address private constant czusd = 0xE68b79e51bf826534Ff37AA9CeE71a3842ee9c70;
    address private constant czb = 0xD963b2236D227a0302E19F2f9595F424950dc186;

    TidalDexFactory private constant factory =
        TidalDexFactory(0x907e8C7D471877b4742dA8aA53d257d0d565A47E);

    TidalDexRouter private constant router =
        TidalDexRouter(payable(0x71aB950a0C349103967e711b931c460E9580c631));

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

        require(lpCzusdBalInitial > 500 ether, "Insufficient CZUSD liquidity");
        require(
            lpCzbBalInitial > 2_000_000 ether,
            "Insufficient CZB liquidity"
        );

        uint256 czusdAmt = lpCzusdBalInitial / 50;

        uint256 czusdInitialTotalSupply = IERC20(czusd).totalSupply();
        uint256 czbInitialTotalSupply = IERC20(czb).totalSupply();

        // 1. Swap CZUSD -> TOKEN -> CZB
        address[] memory path = new address[](3);
        path[0] = czusd;
        path[1] = token;
        path[2] = czb;

        IERC20(czusd).approve(address(router), czusdAmt);
        IERC20Mintable(czusd).mint(address(this), czusdAmt);

        uint256 amt1 = czusdAmt / 2;
        uint256 amt2 = czusdAmt - amt1;

        // buy twice
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amt1,
            0,
            path,
            address(this),
            block.timestamp
        );
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amt2,
            0,
            path,
            address(this),
            block.timestamp
        );

        // 2. As CZB has a burn fee, mint more CZB to cover the fee.
        uint256 czbPostBurnTotalSupply = IERC20(czb).totalSupply();
        uint256 czbAmtToMint = czbInitialTotalSupply - czbPostBurnTotalSupply;
        IERC20Mintable(czb).mint(address(this), czbAmtToMint);

        // 3. Swap CZB -> TOKEN -> CZUSD
        path[0] = czb;
        path[1] = token;
        path[2] = czusd;

        uint256 czbAmt = IERC20(czb).balanceOf(address(this));
        IERC20(czb).approve(address(router), czbAmt);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            czbAmt,
            0,
            path,
            address(this),
            block.timestamp
        );

        // 4. Make sure both pools have the same amount of czb, czusd, and tokens as initially.
        // Token balances
        // The most likely scenario is that the balance of czusdLpToken was too high.
        // This means that the amount of tokens in czb liquidity must be too low.
        // So we swap czusd for tokens to make the balance of czusdLpToken lower.
        // Then we transfer the tokens to the czb liquidity to make the balance of czbLpToken higher.
        // This will make the balance of czusdLpToken and czbLpToken the same as initially.
        if (
            IERC20(token).balanceOf(tokenCzusdLpToken) > tokenBalCzusdLpInitial
        ) {
            address[] memory p = new address[](2);
            p[0] = czusd;
            p[1] = token;
            uint256 amt = IERC20(czusd).balanceOf(address(this)) / 50;
            IERC20(czusd).approve(address(router), amt);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amt,
                0,
                p,
                address(this),
                block.timestamp
            );
            // Since the balance of czusdLpToken was too high
            // we know that the amount of tokens in czb liquidity must be too low.
            IERC20(token).transfer(
                tokenCzbLpToken,
                tokenBalCzbLpInitial - IERC20(token).balanceOf(tokenCzbLpToken)
            );
            IERC20(token).transfer(
                tokenCzusdLpToken,
                IERC20(token).balanceOf(address(this))
            );
        } else if (
            IERC20(token).balanceOf(tokenCzusdLpToken) < tokenBalCzusdLpInitial
        ) {
            // Since the balance of tokenCzusdLpToken was too low
            // it means that the amount of tokens in czb liquidity must be too high.
            // So we swap CZB for tokens, then transfer tokens to the correct ratios.
            address[] memory p = new address[](2);
            uint256 amt = czbAmt / 50;
            IERC20Mintable(czb).mint(address(this), amt);
            p[0] = czb;
            p[1] = token;
            IERC20(czb).approve(address(router), amt);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amt,
                0,
                p,
                address(this),
                block.timestamp
            );
            IERC20(token).transfer(
                tokenCzbLpToken,
                tokenBalCzbLpInitial - IERC20(token).balanceOf(tokenCzbLpToken)
            );
            IERC20(token).transfer(
                tokenCzusdLpToken,
                IERC20(token).balanceOf(address(this))
            );
        }

        // CZUSD balance
        if (IERC20(czusd).balanceOf(tokenCzusdLpToken) > lpCzusdBalInitial) {
            IERC20Burnable(czusd).burnFrom(
                tokenCzusdLpToken,
                IERC20(czusd).balanceOf(tokenCzusdLpToken) - lpCzusdBalInitial
            );
        }
        if (IERC20(czusd).balanceOf(tokenCzusdLpToken) < lpCzusdBalInitial) {
            IERC20Mintable(czusd).mint(
                tokenCzusdLpToken,
                lpCzusdBalInitial - IERC20(czusd).balanceOf(tokenCzusdLpToken)
            );
        }
        IAmmPair(tokenCzusdLpToken).sync();

        // CZB balance
        if (IERC20(czb).balanceOf(tokenCzbLpToken) > lpCzbBalInitial) {
            IERC20Burnable(czb).burnFrom(
                tokenCzbLpToken,
                IERC20(czb).balanceOf(tokenCzbLpToken) - lpCzbBalInitial
            );
        }
        if (IERC20(czb).balanceOf(tokenCzbLpToken) < lpCzbBalInitial) {
            IERC20Mintable(czb).mint(
                tokenCzbLpToken,
                lpCzbBalInitial - IERC20(czb).balanceOf(tokenCzbLpToken)
            );
        }
        IAmmPair(tokenCzbLpToken).sync();

        // 5. Burn the czusd.
        IERC20Burnable(czusd).burn(IERC20(czusd).balanceOf(address(this)));

        // 6. Confirm the total supply of CZUSD and CZB, lp balance, and token balance are the same as initially.
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
}
