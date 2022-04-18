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
contract IUniversalLiquidatorV1 {

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

    function governance() external view returns (address);

    function controller() external view returns (address);

    function nextImplementation() external view returns (address);

    function scheduleUpgrade(address _nextImplementation) external;

    /**
     * Constructor replacement because this contract is meant to be upgradable
     */
    function initializeUniversalLiquidator(
        address _storage
    ) external;

    /**
     * @param _path     The path that is used for selling token at path[0] into path[path.length - 1].
     * @param _router   The router to use for this path.
     */
    function configureSwap(
        address[] calldata _path,
        address _router
    ) external;

    /**
     * @param _paths    The paths that are used for selling token at path[i][0] into path[i][path[i].length - 1].
     * @param _routers  The routers to use for each index, `i`.
     */
    function configureSwaps(
        address[][] calldata _paths,
        address[] calldata _routers
    ) external;

    /**
     * @return The router used to execute the swap from `_inputToken` to `_outputToken`
     */
    function getSwapRouter(
        address _inputToken,
        address _outputToken
    ) external view returns (address);

    function swapTokens(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _recipient
    ) external returns (uint _amountOut);
}
