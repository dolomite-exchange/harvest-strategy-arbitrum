pragma solidity ^0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";


contract VaultStorage is Initializable {

    bytes32 internal constant _STRATEGY_SLOT = 0xf1a169aa0f736c2813818fdfbdc5755c31e0839c8f49831a16543496b28574ea;
    bytes32 internal constant _UNDERLYING_SLOT = 0x1994607607e11d53306ef62e45e3bd85762c58d9bf38b5578bc4a258a26a7371;
    bytes32 internal constant _UNDERLYING_UNIT_SLOT = 0xa66bc57d4b4eed7c7687876ca77997588987307cb13ecc23f5e52725192e5fff;
    bytes32 internal constant _VAULT_FRACTION_TO_INVEST_NUMERATOR_SLOT = 0x39122c9adfb653455d0c05043bd52fcfbc2be864e832efd3abc72ce5a3d7ed5a;
    bytes32 internal constant _VAULT_FRACTION_TO_INVEST_DENOMINATOR_SLOT = 0x469a3bad2fab7b936c45eecd1f5da52af89cead3e2ed7f732b6f3fc92ed32308;
    bytes32 internal constant _NEXT_IMPLEMENTATION_SLOT = 0xb1acf527cd7cd1668b30e5a9a1c0d845714604de29ce560150922c9d8c0937df;
    bytes32 internal constant _NEXT_IMPLEMENTATION_TIMESTAMP_SLOT = 0x3bc747f4b148b37be485de3223c90b4468252967d2ea7f9fcbd8b6e653f434c9;
    bytes32 internal constant _NEXT_STRATEGY_SLOT = 0xcd7bd9250b0e02f3b13eccf8c73ef5543cb618e0004628f9ca53b65fbdbde2d0;
    bytes32 internal constant _NEXT_STRATEGY_TIMESTAMP_SLOT = 0x5d2b24811886ad126f78c499d71a932a5435795e4f2f6552f0900f12d663cdcf;
    bytes32 internal constant _ALLOW_SHARE_PRICE_DECREASE_SLOT = 0x22f7033891e85fc76735ebd320e0d3f546da431c4729c2f6d2613b11923aaaed;
    bytes32 internal constant _WITHDRAW_BEFORE_REINVESTING_SLOT = 0x4215fbb95dc0890d3e1660fb9089350f2d3f350c0a756934874cae6febf42a79;
    bytes32 internal constant _PAUSED_SLOT = 0xf1cf856d03630b74791fc293cfafd739932a5a075b02d357fb7a726a38777930;

    constructor() public {
        assert(_STRATEGY_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.strategy")) - 1));
        assert(_UNDERLYING_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.underlying")) - 1));
        assert(_UNDERLYING_UNIT_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.underlyingUnit")) - 1));
        assert(_VAULT_FRACTION_TO_INVEST_NUMERATOR_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.vaultFractionToInvestNumerator")) - 1));
        assert(_VAULT_FRACTION_TO_INVEST_DENOMINATOR_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.vaultFractionToInvestDenominator")) - 1));
        assert(_NEXT_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.nextImplementation")) - 1));
        assert(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.nextImplementationTimestamp")) - 1));
        assert(_NEXT_STRATEGY_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.nextStrategy")) - 1));
        assert(_NEXT_STRATEGY_TIMESTAMP_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.nextStrategyTimestamp")) - 1));
        assert(_ALLOW_SHARE_PRICE_DECREASE_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.allowSharePriceDecrease")) - 1));
        assert(_WITHDRAW_BEFORE_REINVESTING_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.withdrawBeforeReinvesting")) - 1));
        assert(_PAUSED_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.paused")) - 1));
    }

    function initialize(
        address _underlying,
        uint256 _toInvestNumerator,
        uint256 _toInvestDenominator,
        uint256 _underlyingUnit
    ) public initializer {
        _setUnderlying(_underlying);
        _setVaultFractionToInvestNumerator(_toInvestNumerator);
        _setVaultFractionToInvestDenominator(_toInvestDenominator);
        _setUnderlyingUnit(_underlyingUnit);
        _setNextStrategyTimestamp(0);
        _setNextStrategy(address(0));
        _setAllowSharePriceDecrease(false);
        _setWithdrawBeforeReinvesting(false);
    }

    function _setStrategy(address _address) internal {
        setAddress(_STRATEGY_SLOT, _address);
    }

    function _strategy() internal view returns (address) {
        return getAddress(_STRATEGY_SLOT);
    }

    function _setUnderlying(address _address) internal {
        setAddress(_UNDERLYING_SLOT, _address);
    }

    function _underlying() internal view returns (address) {
        return getAddress(_UNDERLYING_SLOT);
    }

    function _setUnderlyingUnit(uint256 _value) internal {
        setUint256(_UNDERLYING_UNIT_SLOT, _value);
    }

    function _underlyingUnit() internal view returns (uint256) {
        return getUint256(_UNDERLYING_UNIT_SLOT);
    }

    function _setVaultFractionToInvestNumerator(uint256 _value) internal {
        setUint256(_VAULT_FRACTION_TO_INVEST_NUMERATOR_SLOT, _value);
    }

    function _vaultFractionToInvestNumerator() internal view returns (uint256) {
        return getUint256(_VAULT_FRACTION_TO_INVEST_NUMERATOR_SLOT);
    }

    function _setVaultFractionToInvestDenominator(uint256 _value) internal {
        setUint256(_VAULT_FRACTION_TO_INVEST_DENOMINATOR_SLOT, _value);
    }

    function _vaultFractionToInvestDenominator() internal view returns (uint256) {
        return getUint256(_VAULT_FRACTION_TO_INVEST_DENOMINATOR_SLOT);
    }

    function _setAllowSharePriceDecrease(bool _value) internal {
        setBoolean(_ALLOW_SHARE_PRICE_DECREASE_SLOT, _value);
    }

    function _allowSharePriceDecrease() internal view returns (bool) {
        return getBoolean(_ALLOW_SHARE_PRICE_DECREASE_SLOT);
    }

    function _setWithdrawBeforeReinvesting(bool _value) internal {
        setBoolean(_WITHDRAW_BEFORE_REINVESTING_SLOT, _value);
    }

    function _withdrawBeforeReinvesting() internal view returns (bool) {
        return getBoolean(_WITHDRAW_BEFORE_REINVESTING_SLOT);
    }

    function _setNextImplementation(address _address) internal {
        setAddress(_NEXT_IMPLEMENTATION_SLOT, _address);
    }

    function _nextImplementation() internal view returns (address) {
        return getAddress(_NEXT_IMPLEMENTATION_SLOT);
    }

    function _setNextImplementationTimestamp(uint256 _value) internal {
        setUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT, _value);
    }

    function _nextImplementationTimestamp() internal view returns (uint256) {
        return getUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT);
    }

    function _setNextStrategy(address _value) internal {
        setAddress(_NEXT_STRATEGY_SLOT, _value);
    }

    function _nextStrategy() internal view returns (address) {
        return getAddress(_NEXT_STRATEGY_SLOT);
    }

    function _setNextStrategyTimestamp(uint256 _value) internal {
        setUint256(_NEXT_STRATEGY_TIMESTAMP_SLOT, _value);
    }

    function _nextStrategyTimestamp() internal view returns (uint256) {
        return getUint256(_NEXT_STRATEGY_TIMESTAMP_SLOT);
    }

    function _paused() internal view returns (bool) {
        return getBoolean(_PAUSED_SLOT);
    }

    function _setPaused(bool _value) internal {
        setBoolean(_PAUSED_SLOT, _value);
    }

    function setBoolean(bytes32 slot, bool _value) internal {
        setUint256(slot, _value ? 1 : 0);
    }

    function getBoolean(bytes32 slot) internal view returns (bool) {
        return (getUint256(slot) == 1);
    }

    function setAddress(bytes32 slot, address _address) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _address)
        }
    }

    function setUint256(bytes32 slot, uint256 _value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _value)
        }
    }

    function getAddress(bytes32 slot) internal view returns (address str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    function getUint256(bytes32 slot) internal view returns (uint256 str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    uint256[50] private ______gap;
}
