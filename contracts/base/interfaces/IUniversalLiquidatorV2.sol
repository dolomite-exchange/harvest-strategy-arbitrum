// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./IUniversalLiquidatorV1.sol";


/**
 * @dev A contract that handles all liquidations from an `inputToken` to an `outputToken`. This contract simplifies
 *      all swap logic so strategies can be focused on management of funds and forwarding gains to this contract
 *      for the most efficient liquidation. If the liquidation path of an asset changes, governance needs only to
 *      create a new instance of this contract or modify the liquidation path via `configureSwap`, and all callers of
 *      the contract benefit from the change and uniformity.
 */
contract IUniversalLiquidatorV2 is IUniversalLiquidatorV1 {

    /**
     * @param _path         The path that is used for selling token at path[0] into path[path.length - 1].
     * @param _router       The router to use for this path.
     * @param _extraData    Any additional data needed to execute the swap for this path and router.
     */
    function configureSwap(
        address[] calldata _path,
        address _router,
        bytes calldata _extraData
    ) external;

    /**
     * @param _paths        The paths that are used for selling token at path[i][0] into path[i][path[i].length - 1].
     * @param _routers      The routers to use for each index, `i`.
     * @param _extraDatas   Any additional data needed to execute the swap for this path and router.
     */
    function configureSwaps(
        address[][] calldata _paths,
        address[] calldata _routers,
        bytes[] calldata _extraDatas
    ) external;

    function getExtraData(
        address _router,
        address _tokenIn,
        address _tokenOut
    ) external view returns (bytes memory extraData);
}
