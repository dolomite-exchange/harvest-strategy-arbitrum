pragma solidity ^0.5.16;

import "./interfaces/IControllerV2.sol";
import "./ControllerV1.sol";


contract ControllerV2 is ControllerV1, IControllerV2 {

    // ========================= Fields =========================

    /// how long each TWAP sampling must be, at least, for updates to be considered valid
    uint256 public vaultOraclePriceUpdateDuration;
    uint256 public nextVaultOraclePriceUpdateDuration;
    uint256 public nextVaultOraclePriceUpdateDurationTimestamp;

    // ========================= Modifiers =========================

    constructor(
        address _controllerV1,
        address[] memory _hardWorkers,
        address[] memory _vaults,
        address[] memory _strategies
    )
    ControllerV1(
        IController(_controllerV1).store(),
        IController(_controllerV1).targetToken(),
        IController(_controllerV1).profitSharingReceiver(),
        IController(_controllerV1).rewardForwarder(),
        IController(_controllerV1).universalLiquidator(),
        IController(_controllerV1).nextImplementationDelay()
    )
    public {
        require(
            _vaults.length == _strategies.length,
            "invalid vaults/strategies length"
        );

        for (uint i = 0; i < _hardWorkers.length; i++) {
            hardWorkers[_hardWorkers[i]] = true;
        }
        for (uint i = 0; i < _vaults.length; i++) {
            _addVaultAndStrategy(_vaults[i], _strategies[i]);
        }
        vaultOraclePriceUpdateDuration = 15 minutes;

        profitSharingNumerator = IController(_controllerV1).profitSharingNumerator();
        strategistFeeNumerator = IController(_controllerV1).strategistFeeNumerator();
        platformFeeNumerator = IController(_controllerV1).platformFeeNumerator();
    }

    function setNextVaultOraclePriceUpdateDuration(
        uint256 _nextVaultOraclePriceUpdateDuration
    ) public onlyGovernance {
        require(
            _nextVaultOraclePriceUpdateDuration > 0,
            "invalid _nextVaultOraclePriceUpdateDuration"
        );

        nextVaultOraclePriceUpdateDuration = _nextVaultOraclePriceUpdateDuration;
        nextVaultOraclePriceUpdateDurationTimestamp = block.timestamp + nextVaultOraclePriceUpdateDuration;
        emit QueueNextVaultOraclePriceUpdateDuration(
            nextVaultOraclePriceUpdateDuration,
            nextVaultOraclePriceUpdateDurationTimestamp
        );
    }

    function confirmNextVaultOraclePriceUpdateDuration() public onlyGovernance {
        require(
            nextVaultOraclePriceUpdateDurationTimestamp != 0 &&
            block.timestamp >= nextVaultOraclePriceUpdateDurationTimestamp,
            "invalid timestamp or no new implementation delay confirmed"
        );
        nextVaultOraclePriceUpdateDuration = nextVaultOraclePriceUpdateDuration;
        nextVaultOraclePriceUpdateDuration = 0;
        nextVaultOraclePriceUpdateDurationTimestamp = 0;
        emit ConfirmNextVaultOraclePriceUpdateDuration(nextVaultOraclePriceUpdateDuration);
    }
}
