// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {IAmmRouter02} from "../interfaces/IAmmRouter02.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Burnable} from "../interfaces/IERC20Burnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IWETH} from "../interfaces/IWETH.sol";

/**
 * @title TokenBurningAndLP
 * @dev A contract that manages the burning of a subject token and creates liquidity pairs with a base token.
 * The contract handles receiving tokens or ETH, converting to the subject and base tokens, adding liquidity
 * to AMM pools, and burning a portion of the subject token to reduce supply.
 */
contract TokenBurningAndLP is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    /// @notice Role required to execute swap operations to prevent sandwich attacks
    bytes32 public constant SWAPPER_ROLE = keccak256("SWAPPER_ROLE");

    /// @notice The token that is being burned and LP'd
    IERC20Burnable public immutable subjectToken;

    /// @notice The token that is liquidity paired with the subject token
    IERC20 public immutable baseToken;

    /// @notice The token that is paired with the expected received tokens and the base token
    IERC20 public immutable intermediateToken;

    /// @notice The AMM router used to create the LP and execute swaps
    IAmmRouter02 public immutable router;

    /// @notice The liquidity ratio in basis points (10000 = 100%)
    uint256 public immutable liquidityRatio;

    /**
     * @notice Initializes the TokenBurningAndLP contract
     * @param _admin Address that will be granted the DEFAULT_ADMIN_ROLE
     * @param _subjectToken The token that will be burned and added to liquidity
     * @param _baseToken The token to pair with the subject token for liquidity
     * @param _router The AMM router used for swaps and liquidity provision
     * @param _liquidityRatio The ratio of tokens to be used for liquidity in basis points
     */
    constructor(
        address _admin,
        IERC20Burnable _subjectToken,
        IERC20 _baseToken,
        IERC20 _intermediateToken,
        IAmmRouter02 _router,
        uint256 _liquidityRatio
    ) {
        subjectToken = _subjectToken;
        baseToken = _baseToken;
        intermediateToken = _intermediateToken;
        router = _router;
        liquidityRatio = _liquidityRatio;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Transfers tokens from the caller to this contract
     * @dev Anyone can call this method to contribute tokens to the burning and LP mechanism
     * @param _receivedToken The token to transfer from the caller
     * @param _amount The amount of tokens to transfer
     */
    function transferReceivedToken(
        IERC20 _receivedToken,
        uint256 _amount
    ) external {
        _receivedToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice Receives ETH and wraps it to WETH
     * @dev Anyone can call this method to contribute ETH to the burning and LP mechanism
     */
    function receiveETH() external payable {
        IWETH(router.WETH()).deposit{value: msg.value}();
    }

    /**
     * @notice Swaps the intermediate token for the base token
     * @dev Restricted to SWAPPER_ROLE to prevent sandwich attacks
     * @param _minAmountOut The minimum amount of base token to receive
     */
    function swapIntermediateTokenForBaseToken(
        uint256 _amount,
        uint256 _minAmountOut
    ) external onlyRole(SWAPPER_ROLE) {
        // Swap the intermediate token for the base token
        address[] memory path = new address[](2);
        path[0] = address(intermediateToken);
        path[1] = address(baseToken);
        intermediateToken.approve(
            address(router),
            intermediateToken.balanceOf(address(this))
        );
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            _minAmountOut,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @notice Swaps any received token for the base token
     * @dev Restricted to SWAPPER_ROLE to prevent sandwich attacks
     * @param _receivedToken The token to swap for the base token
     */
    function swapReceivedTokenForBaseToken(
        IERC20 _receivedToken,
        uint256 _minAmountOut
    ) external onlyRole(SWAPPER_ROLE) {
        // Swap the received token to the base token
        address[] memory path = new address[](3);
        path[0] = address(_receivedToken);
        path[1] = address(intermediateToken);
        path[2] = address(baseToken);
        _receivedToken.approve(
            address(router),
            _receivedToken.balanceOf(address(this))
        );
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _receivedToken.balanceOf(address(this)),
            _minAmountOut,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @notice Performs the main token burning and liquidity provision logic
     * @dev Restricted to SWAPPER_ROLE to prevent sandwich attacks
     * @param _amount The amount of base token to process (0 means use all available)
     */
    function swapBaseTokenForSubjectToken(
        uint256 _amount,
        uint256 _minAmountOut
    ) external onlyRole(SWAPPER_ROLE) {
        if (_amount == 0) {
            _amount = baseToken.balanceOf(address(this));
        }

        // Amount to NOT swap is the liquidity ratio basis points divided by 2
        // half of the liquidity ratio is used to swap the base token for the subject token
        // Remainder is burned
        uint256 amountForLP = ((_amount * liquidityRatio) / 2) / 10_000;
        uint256 amountToSwap = _amount - amountForLP;

        // Swap the base token for the subject token
        address[] memory path = new address[](2);
        path[0] = address(baseToken);
        path[1] = address(subjectToken);

        // Approve the router to spend the base token
        baseToken.approve(address(router), amountToSwap);

        // Swap the base token for the subject token
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountToSwap,
            _minAmountOut,
            path,
            address(this),
            block.timestamp
        );

        // Mint LP
        // Approve the router to spend the subject token
        subjectToken.approve(
            address(router),
            subjectToken.balanceOf(address(this))
        );
        baseToken.approve(address(router), baseToken.balanceOf(address(this)));

        // Mint LP
        router.addLiquidity(
            address(subjectToken),
            address(baseToken),
            (subjectToken.balanceOf(address(this)) * amountToSwap) /
                amountToSwap,
            amountForLP, // amount of base that was not swapped, so that it is available for liquidity
            1,
            1,
            address(0x0000000000000000000000000000000000000000), //Burn address
            block.timestamp
        );

        // Burn the subject token
        subjectToken.burn(subjectToken.balanceOf(address(this)));
    }
}
