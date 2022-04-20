pragma solidity ^0.5.16;

import "./interfaces/IControllerV2.sol";
import "./interfaces/IVaultV3.sol";
import "./VaultV2.sol";


contract VaultV3 is VaultV2, IVaultV3 {

    // ========================= Events =========================

    event PriceCumulativeSet(uint256 _priceCumulative);
    event OraclePriceSet(uint256 _oraclePrice);
    event LastOraclePriceUpdateTimestampSet(uint256 _lastOraclePriceUpdateTimestamp);

    // ========================= Constants =========================

    bytes32 internal constant _PRICE_CUMULATIVE_SLOT = 0x348c3e8fe3914969ace0ebe9744ce83625957c5f0dbe03eff7d6adc1beade0fa;
    bytes32 internal constant _ORACLE_PRICE_SLOT = 0xbbbc73a48f61790a61a1989fac39ee9daa03ed8f59ab187e02a3536f6314f90e;
    bytes32 internal constant _LAST_ORACLE_PRICE_UPDATE_TIMESTAMP_SLOT = 0x46abf45e9edc21d90f240c3b2b74e50ca17dbe7039a7c6071ae90ac4d0ac3751;

    // ========================= Public Functions =========================

    constructor() public {
        assert(_PRICE_CUMULATIVE_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.priceCumulative")) - 1));
        assert(_ORACLE_PRICE_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.oraclePrice")) - 1));
        assert(_LAST_ORACLE_PRICE_UPDATE_TIMESTAMP_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.lastOraclePriceUpdateTimestamp")) - 1));
    }

    function finalizeUpgrade() external onlyGovernance {
        _setNextImplementation(address(0));
        _setNextImplementationTimestamp(0);

        _setPriceCumulative(getPricePerFullShare());
        _setOraclePrice(getPricePerFullShare());
        _setLastOraclePriceUpdateTimestamp(block.timestamp);
        emit VaultChanged(_implementation());
    }

    function priceCumulative() public view returns (uint256) {
        return getUint256(_PRICE_CUMULATIVE_SLOT);
    }

    function oraclePrice() public view returns (uint256) {
        return getUint256(_ORACLE_PRICE_SLOT);
    }

    function lastOraclePriceUpdateTimestamp() public view returns (uint256) {
        return getUint256(_LAST_ORACLE_PRICE_UPDATE_TIMESTAMP_SLOT);
    }

    function doHardWork() whenStrategyDefined onlyControllerOrGovernance external {
        uint256 vaultOraclePriceUpdateDuration = IControllerV2(controller()).vaultOraclePriceUpdateDuration();
        uint256 timeElapsed = block.timestamp - lastOraclePriceUpdateTimestamp();
        if (timeElapsed >= vaultOraclePriceUpdateDuration) {
            // Enough time has passed to perform an oracle update
            uint256 priceCumulativeLast = priceCumulative();
            uint256 priceCumulativeNew = priceCumulativeLast + (timeElapsed * getPricePerFullShare());

            _setPriceCumulative(priceCumulativeNew);
            _setOraclePrice((priceCumulativeNew - priceCumulativeLast) / timeElapsed);
            _setLastOraclePriceUpdateTimestamp(block.timestamp);
        }

        // ensure that new funds are invested too
        _invest();
        IStrategy(strategy()).doHardWork();
    }

    // ========================= Internal Functions =========================

    function _setPriceCumulative(uint256 _priceCumulative) internal {
        setUint256(_PRICE_CUMULATIVE_SLOT, _priceCumulative);
        emit PriceCumulativeSet(_priceCumulative);
    }

    function _setOraclePrice(uint256 _oraclePrice) internal {
        setUint256(_ORACLE_PRICE_SLOT, _oraclePrice);
        emit OraclePriceSet(_oraclePrice);
    }

    function _setLastOraclePriceUpdateTimestamp(uint256 _lastOraclePriceUpdateTimestamp) internal {
        setUint256(_LAST_ORACLE_PRICE_UPDATE_TIMESTAMP_SLOT, _lastOraclePriceUpdateTimestamp);
        emit LastOraclePriceUpdateTimestampSet(_lastOraclePriceUpdateTimestamp);
    }
}
