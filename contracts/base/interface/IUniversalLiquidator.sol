// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;


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
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _recipient
    ) external returns (uint _amountOut);
}
