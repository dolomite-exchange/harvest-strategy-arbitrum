pragma solidity ^0.5.16;

/// @title  Interface for transforming tokens into productive fTokens for yield farming with Harvest Finance;
/// @author coreycaplan3 from Dolomite
/// @dev    This interface is responsible for transforming a user's deposit & borrowed funds into yield farmed asset
///         (fToken). This contract must set an allowance on `msg.sender` so the caller can `transferFrom` `fAmount`
///         into the calling contract. `msg.sender` must also have an allowance set on this contract (the reverse of
///         the prior sentence) so it can pull transformative `tokens` into this contract.
interface IDolomiteAssetTransformer {

    /**
     * @returns fToken  The token that this transformer creates upon a call to `transform`.
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
     * @return              The amount of `fToken` that was transformed via `tokens` and `amounts`.
     */
    function transform(
        address[] calldata tokens,
        uint[] calldata amount,
        address dustRecipient
    ) external returns (uint fAmount);

    /**
     * @notice              The calling contract must have an allowance set so this contract can pull `fAmount` tokens
     *                      from `msg.sender` into this contract.
     * @param fAmount       The amount of fTokens to convert back to their original format
     * @param outputTokens  The tokens that should be outputted, by converting the fToken back to its origin format.
     * @return              The tokens that were outputted, same as `outputTokens` and `amounts`
     */
    function transformBack(
        uint fAmount,
        address[] calldata outputTokens
    ) external returns (address[] memory tokens, uint[] memory amounts);

}