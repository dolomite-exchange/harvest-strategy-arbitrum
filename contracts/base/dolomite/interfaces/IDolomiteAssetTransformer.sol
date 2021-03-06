/*

    Copyright 2021 Dolomite.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity ^0.5.16;

/// @title  Interface for transforming tokens into productive fTokens for yield farming with Harvest Finance;
/// @author coreycaplan3 from Dolomite
/// @dev    This interface is responsible for transforming a user's deposit & borrowed funds into yield farmed asset
///         (fToken). This contract must set an allowance on `msg.sender` so the caller can `transferFrom` `fAmount`
///         into the calling contract. `msg.sender` must also have an allowance set on this contract (the reverse of
///         the prior sentence) so it can pull transformative `tokens` into this contract.
interface IDolomiteAssetTransformer {

    /**
     * @return fToken  The token that this transformer creates upon a call to `transform`.
     */
    function fToken() external view returns (address);

    /**
     * @notice              This contract must have an allowance set so `msg.sender` can pull `fAmount` tokens into
     *                      `msg.sender` from this contract. `msg.sender` must have an allowance set so this contract
     *                      can pull `amounts` of `tokens` into this contract.
     * @param tokens        The deposit and borrowed tokens that will be transformed into this transformer's `fToken`.
     * @param amounts       The amount of `tokens` that will be pulled into this contract for transformation. Each
     *                      index of `tokens` corresponds with an index of `amounts`.
     * @param dustRecipient The address that will receive any leftover `tokens` in case a full deposit cannot be made.
     *                      Can be set to `address(0)` to deny receiving leftover dust. The only reason to do this is
     *                      to lower the gas fees, since doing so would lessen the number of transfers.
     * @param extraData     Any extra data needed to be passed along for doing safety checks (like checking deadlines,
     *                      slippage, etc.)
     * @return              The amount of `fToken` that was transformed via `tokens` and `amounts`.
     */
    function transform(
        address[] calldata tokens,
        uint[] calldata amounts,
        address dustRecipient,
        bytes calldata extraData
    ) external returns (uint fAmount);

    /**
     * @notice              Calculates the `amounts` of `tokens` that will be returned, upon converting `tokens` to
     *                      `fToken`.
     * @param tokens        The deposit and borrowed tokens that will be transformed into this transformer's `fToken`.
     * @param amounts       The amount of `tokens` that will be pulled into this contract for transformation. Each
     *                      index of `tokens` corresponds with an index of `amounts`.
     * @return              The amount of `fToken` that was transformed via `tokens` and `amounts`.
     */
    function getTransformationResult(
        address[] calldata tokens,
        uint[] calldata amounts
    ) external returns (uint fAmount);

    /**
     * @notice              The calling contract must have an allowance set so this contract can pull `fAmount` tokens
     *                      from `msg.sender` into this contract.
     * @param fAmount       The amount of fTokens to convert back to their original format
     * @param outputTokens  The tokens that should be outputted, by converting the fToken back to its origin format.
     * @param extraData     Any extra data needed to be passed along for doing safety checks (like checking deadlines,
     *                      slippage, etc.)
     * @return              The amounts that were outputted, each index corresponds with `outputTokens`
     */
    function transformBack(
        uint fAmount,
        address[] calldata outputTokens,
        bytes calldata extraData
    ) external returns (uint[] memory outputAmounts);


    /**
     * @notice              Calculates the `amounts` of `tokens` that will be returned, upon converting fToken back to
     *                      its underlying `outputTokens`
     * @param fAmount       The amount of fTokens to convert back to their original format
     * @param outputTokens  The tokens that should be outputted, by converting the fToken back to its origin format.
     * @return              The amounts that were outputted, each index corresponds with `outputTokens`
     */
    function getTransformBackResult(
        uint fAmount,
        address[] calldata outputTokens
    ) external view returns (uint[] memory outputAmounts);

}
