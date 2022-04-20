pragma solidity ^0.5.16;


interface IControllerV2 {

    // ========================= Events =========================

    event QueueNextVaultOraclePriceUpdateDuration(
        uint256 nextVaultOraclePriceUpdateDuration,
        uint256 nextVaultOraclePriceUpdateDurationTimestamp
    );

    event ConfirmNextVaultOraclePriceUpdateDuration(
        uint256 nextVaultOraclePriceUpdateDuration
    );

    // ========================= View Functions =========================

    function vaultOraclePriceUpdateDuration() external view returns (uint256);

    function nextVaultOraclePriceUpdateDuration() external view returns (uint256);

    function nextVaultOraclePriceUpdateDurationTimestamp() external view returns (uint256);
}
