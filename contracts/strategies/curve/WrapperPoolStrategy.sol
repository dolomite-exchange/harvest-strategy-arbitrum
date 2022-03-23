pragma solidity ^0.5.16;

import "./CurveStrategy.sol";


/**
 * @dev Wraps around an existing Curve pool to execute a strategy. IE EURs-USD pool wraps around 2Pool
 */
contract WrapperPoolStrategy is CurveStrategy {

    // ========================= Additional Storage Slots =========================

    bytes32 internal constant _WRAPPER_DEPOSIT_TOKEN_SLOT = 0x7c1af11777174e1b5ebacde3f28e34d6d0eed7689ffdde8198fa41475889b44b;
    bytes32 internal constant _WRAPPER_DEPOSIT_ARRAY_POSITION_SLOT = 0xea946ec6ce96c549b4f8c9c3fa26d497c32610f4616147feb0ed1400b7ee1fcd;
    bytes32 internal constant _CRV_WRAPPER_DEPOSIT_POOL_SLOT = 0x2e2d2989971956ab87aa0f1f449b51785a32cdb2d035840b1153efae27d55bf5;

    constructor() public CurveStrategy() {
        assert(_WRAPPER_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.wrapperDepositToken")) - 1));
        assert(_WRAPPER_DEPOSIT_ARRAY_POSITION_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.wrapperDepositArrayPosition")) - 1));
        assert(_CRV_WRAPPER_DEPOSIT_POOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.wrapperCrvDepositPool")) - 1));
    }

    function initializeWrappedCurveStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address[] memory _rewardTokens,
        address _strategist,
        address _crvDepositPool,
        address _crvDepositToken,
        uint256 _depositArrayPosition,
        address _wrapperCrvDepositPool,
        address _wrapperCrvDepositToken,
        uint256 _wrapperDepositArrayPosition
    ) public initializer {
        CurveStrategy.initializeCurveStrategy(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens,
            _strategist,
            _crvDepositPool,
            _crvDepositToken,
            _depositArrayPosition
        );

        setAddress(_CRV_WRAPPER_DEPOSIT_POOL_SLOT, _wrapperCrvDepositPool);
        setAddress(_WRAPPER_DEPOSIT_TOKEN_SLOT, _wrapperCrvDepositToken);
        setUint256(_WRAPPER_DEPOSIT_ARRAY_POSITION_SLOT, _wrapperDepositArrayPosition);
    }

    function wrapperDepositToken() public view returns (address) {
        return getAddress(_WRAPPER_DEPOSIT_TOKEN_SLOT);
    }

    function wrapperDepositArrayPosition() public view returns (uint256) {
        return getUint256(_WRAPPER_DEPOSIT_ARRAY_POSITION_SLOT);
    }

    function wrapperCurveDepositPool() public view returns (address) {
        return getAddress(_CRV_WRAPPER_DEPOSIT_POOL_SLOT);
    }
}
