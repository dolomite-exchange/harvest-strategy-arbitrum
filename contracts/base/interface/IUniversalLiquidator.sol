// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

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
     * @path The path that is used for selling token at path[0] into path[path.length - 1]
     * @dexs The DEX to use for each step in the path. Must be `path.length - 1`. Each uint represents a different DEX
     */
    function configureSwap(
        address[] memory path,
        uint[] memory dexs
    ) external;

    // TODO refactor and simplify to the following. Where `path` is pieced into iterations of tokenA and tokenB, and the
    // TODO ideal DEX is read from storage
    function swapToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _recipient,
        address[] calldata _path
    ) external;

    function getDexForSwap() external view returns (bytes32);
}
