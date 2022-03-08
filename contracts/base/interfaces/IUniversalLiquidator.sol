// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;


/**
 * @dev A contract that handles all liquidations from an `inputToken` to an `outputToken`. This contract simplifies
 *      all swap logic so strategies can be focused on management of funds and forwarding gains to this contract
 *      for the most efficient liquidation. If the liquidation path of an asset changes, governance needs only to
 *      create a new instance of this contract or modify the liquidation path via `configureSwap`, and all callers of
 *      the contract benefit from the change and uniformity.
 */
interface IUniversalLiquidator {

    // ==================== Events ====================

    event Swap(
        address indexed buyToken,
        address indexed sellToken,
        address indexed recipient,
        address initiator,
        uint256 amountIn,
        uint256 slippage,
        uint256 total
    );

    // ==================== Functions ====================

    /**
     * @param path      The path that is used for selling token at path[0] into path[path.length - 1].
     * @param router    The router to use for this path.
     */
    function configureSwap(
        address[] calldata path,
        address router
    ) external;

    /**
     * @param paths     The paths that are used for selling token at path[i][0] into path[i][path[i].length - 1].
     * @param routers   The routers to use for each index, `i`.
     */
    function configureSwaps(
        address[][] calldata paths,
        address[] calldata routers
    ) external;

    /**
     * @return The router used to execute the swap from `inputToken` to `outputToken`
     */
    function getSwapRouter(address inputToken, address outputToken) external view returns (address);

    function swapTokens(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _recipient
    ) external returns (uint _amountOut);
}
