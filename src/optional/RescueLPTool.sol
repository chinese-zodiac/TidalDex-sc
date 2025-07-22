// SPDX-License-Identifier: AGPL-3.0-only
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {IERC20Mintable} from "../interfaces/IERC20Mintable.sol";
import {IERC20Burnable} from "../interfaces/IERC20Burnable.sol";
import {IAmmPair} from "../interfaces/IAmmPair.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TidalDexRouter} from "../TidalDexRouter.sol";
import {TidalDexFactory} from "../TidalDexFactory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPausable} from "../interfaces/IPausable.sol";

contract RescueTokenFromLPViaMintTool is Ownable, ReentrancyGuard {
    address public constant czusd = 0xE68b79e51bf826534Ff37AA9CeE71a3842ee9c70;
    address public constant czb = 0xD963b2236D227a0302E19F2f9595F424950dc186;

    TidalDexFactory public constant factory =
        TidalDexFactory(0x907e8C7D471877b4742dA8aA53d257d0d565A47E);

    TidalDexRouter public constant router =
        TidalDexRouter(payable(0x71aB950a0C349103967e711b931c460E9580c631));

    constructor(address _owner) Ownable(_owner) {}

    function rescueTokenFromLP(
        address trappedToken
    ) external onlyOwner nonReentrant {
        _rescueTokenFromLPViaMint(trappedToken, czusd);
        _rescueTokenFromLPViaMint(trappedToken, czb);
        _transferTokenBalanceToOwner(trappedToken);
    }

    function rescueTokenFromLPCzusdOnly(
        address trappedToken
    ) external onlyOwner nonReentrant {
        _rescueTokenFromLPViaMint(trappedToken, czusd);
        _transferTokenBalanceToOwner(trappedToken);
    }

    function rescueTokenFromLPCzbOnly(
        address trappedToken
    ) external onlyOwner nonReentrant {
        _rescueTokenFromLPViaMint(trappedToken, czb);
        _transferTokenBalanceToOwner(trappedToken);
    }

    function _revertIfTokenNotPaused(address token) internal view {
        require(ERC20Pausable(token).paused(), "Token is not paused");
    }

    function _rescueTokenFromLPViaMint(
        address trappedToken,
        address mintToken
    ) internal {
        _revertIfTokenNotPaused(mintToken);

        IPausable(mintToken).unpause();

        address lpToken = factory.getPair(trappedToken, mintToken);
        uint256 initialMintTokenTotalSupply = IERC20(mintToken).totalSupply();

        uint256 mintTokenTrappedAmount = IERC20(mintToken).balanceOf(lpToken);

        uint256 mintTokenMintAmount = mintTokenTrappedAmount * 100_000;

        IERC20Mintable(mintToken).mint(address(this), mintTokenMintAmount);

        _swapExactTokensForTokens(mintToken, trappedToken, mintTokenMintAmount);

        _burnSyncTokenInLp(mintToken, lpToken);

        _requireTokenTotalSupplyLessThan(
            mintToken,
            initialMintTokenTotalSupply
        );

        IPausable(mintToken).pause();
    }

    function _requireTokenTotalSupplyLessThan(
        address token,
        uint256 amount
    ) internal view {
        uint256 tokenTotalSupply = IERC20(token).totalSupply();
        require(tokenTotalSupply < amount, "Token supply mismatch");
    }

    function _swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        IERC20(tokenIn).approve(address(router), amountIn);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _burnSyncTokenInLp(address token, address lpToken) internal {
        uint256 tokenInLpBal = IERC20(token).balanceOf(lpToken);
        IERC20Burnable(token).burnFrom(lpToken, tokenInLpBal);
        IAmmPair(lpToken).sync();
    }

    function _transferTokenBalanceToOwner(address token) internal {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, tokenBalance);
    }

    function rescueToken(address token) external onlyOwner nonReentrant {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, tokenBalance);
    }
}
