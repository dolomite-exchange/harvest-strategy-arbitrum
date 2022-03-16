pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "../inheritance/ControllableInit.sol";

import "../interfaces/IController.sol";
import "../interfaces/IRewardForwarder.sol";
import "../interfaces/IUpgradeSource.sol";


contract BaseUpgradeableStrategyStorage is IUpgradeSource, ControllableInit {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // ==================== Events ====================

    event ProfitsNotCollected(address indexed rewardToken, bool sell, bool floor);
    event ProfitLogInReward(address indexed rewardToken, uint256 profitAmount, uint256 feeAmount, uint256 timestamp);
    event ProfitAndBuybackLog(address indexed rewardToken, uint256 profitAmount, uint256 feeAmount, uint256 timestamp);
    event PlatformFeeLogInReward(
        address indexed treasury,
        address indexed rewardToken,
        uint256 profitAmount,
        uint256 feeAmount,
        uint256 timestamp
    );
    event StrategistFeeLogInReward(
        address indexed strategist,
        address indexed rewardToken,
        uint256 profitAmount,
        uint256 feeAmount,
        uint256 timestamp
    );

    // ==================== Internal Constants ====================

    bytes32 internal constant _UNDERLYING_SLOT = 0xa1709211eeccf8f4ad5b6700d52a1a9525b5f5ae1e9e5f9e5a0c2fc23c86e530;
    bytes32 internal constant _VAULT_SLOT = 0xefd7c7d9ef1040fc87e7ad11fe15f86e1d11e1df03c6d7c87f7e1f4041f08d41;

    bytes32 internal constant _REWARD_TOKENS_SLOT = 0x45418d9b5c2787ae64acbffccad43f2b487c1a16e24385aa9d2b059f9d1d163c;
    bytes32 internal constant _REWARD_POOL_SLOT = 0x3d9bb16e77837e25cada0cf894835418b38e8e18fbec6cfd192eb344bebfa6b8;
    bytes32 internal constant _SELL_FLOOR_SLOT = 0xc403216a7704d160f6a3b5c3b149a1226a6080f0a5dd27b27d9ba9c022fa0afc;
    bytes32 internal constant _SELL_SLOT = 0x656de32df98753b07482576beb0d00a6b949ebf84c066c765f54f26725221bb6;
    bytes32 internal constant _PAUSED_INVESTING_SLOT = 0xa07a20a2d463a602c2b891eb35f244624d9068572811f63d0e094072fb54591a;

    bytes32 internal constant _PROFIT_SHARING_NUMERATOR_SLOT = 0xe3ee74fb7893020b457d8071ed1ef76ace2bf4903abd7b24d3ce312e9c72c029;
    bytes32 internal constant _PROFIT_SHARING_DENOMINATOR_SLOT = 0x0286fd414602b432a8c80a0125e9a25de9bba96da9d5068c832ff73f09208a3b;

    bytes32 internal constant _NEXT_IMPLEMENTATION_SLOT = 0x29f7fcd4fe2517c1963807a1ec27b0e45e67c60a874d5eeac7a0b1ab1bb84447;
    bytes32 internal constant _NEXT_IMPLEMENTATION_TIMESTAMP_SLOT = 0x414c5263b05428f1be1bfa98e25407cc78dd031d0d3cd2a2e3d63b488804f22e;
    bytes32 internal constant _NEXT_IMPLEMENTATION_DELAY_SLOT = 0x82b330ca72bcd6db11a26f10ce47ebcfe574a9c646bccbc6f1cd4478eae16b31;

    bytes32 internal constant _REWARD_CLAIMABLE_SLOT = 0xbc7c0d42a71b75c3129b337a259c346200f901408f273707402da4b51db3b8e7;
    bytes32 internal constant _STRATEGIST_SLOT = 0x6a7b588c950d46e2de3db2f157e5e0e4f29054c8d60f17bf0c30352e223a458d;

    constructor() public {
        assert(_UNDERLYING_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.underlying")) - 1));
        assert(_VAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.vault")) - 1));
        assert(_REWARD_TOKENS_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.rewardTokens")) - 1));
        assert(_REWARD_POOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.rewardPool")) - 1));
        assert(_SELL_FLOOR_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.sellFloor")) - 1));
        assert(_SELL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.sell")) - 1));
        assert(_PAUSED_INVESTING_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.pausedInvesting")) - 1));

        assert(_PROFIT_SHARING_NUMERATOR_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.profitSharingNumerator")) - 1));
        assert(_PROFIT_SHARING_DENOMINATOR_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.profitSharingDenominator")) - 1));

        assert(_NEXT_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nextImplementation")) - 1));
        assert(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nextImplementationTimestamp")) - 1));
        assert(_NEXT_IMPLEMENTATION_DELAY_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.nextImplementationDelay")) - 1));

        assert(_REWARD_CLAIMABLE_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.rewardClaimable")) - 1));
        assert(_STRATEGIST_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.strategist")) - 1));
    }

    // ==================== Internal Functions ====================

    function _setUnderlying(address _address) internal {
        setAddress(_UNDERLYING_SLOT, _address);
    }

    function underlying() public view returns (address) {
        return getAddress(_UNDERLYING_SLOT);
    }

    function _setRewardPool(address _address) internal {
        setAddress(_REWARD_POOL_SLOT, _address);
    }

    function rewardPool() public view returns (address) {
        return getAddress(_REWARD_POOL_SLOT);
    }

    function _setRewardTokens(address[] memory _addresses) internal {
        setAddressArray(_REWARD_TOKENS_SLOT, _addresses);
    }

    function isRewardToken(address _token) public view returns (bool) {
        address[] memory tokens = rewardTokens();
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == _token) {
                return true;
            }
        }
        return false;
    }

    function rewardTokens() public view returns (address[] memory) {
        return getAddressArray(_REWARD_TOKENS_SLOT);
    }

    function _setVault(address _address) internal {
        setAddress(_VAULT_SLOT, _address);
    }

    function vault() public view returns (address) {
        return getAddress(_VAULT_SLOT);
    }

    function _setStrategist(address _address) internal {
        setAddress(_STRATEGIST_SLOT, _address);
    }

    function strategist() public view returns (address) {
        return getAddress(_STRATEGIST_SLOT);
    }

    /**
     * @dev a flag for disabling selling for simplified emergency exit
     */
    function _setSell(bool _value) internal {
        setBoolean(_SELL_SLOT, _value);
    }

    function sell() public view returns (bool) {
        return getBoolean(_SELL_SLOT);
    }

    function _setPausedInvesting(bool _value) internal {
        setBoolean(_PAUSED_INVESTING_SLOT, _value);
    }

    function pausedInvesting() public view returns (bool) {
        return getBoolean(_PAUSED_INVESTING_SLOT);
    }

    function _setSellFloor(uint256 _value) internal {
        setUint256(_SELL_FLOOR_SLOT, _value);
    }

    function sellFloor() public view returns (uint256) {
        return getUint256(_SELL_FLOOR_SLOT);
    }

    function profitSharingNumerator() public view returns (uint256) {
        return IController(controller()).profitSharingNumerator();
    }

    function profitSharingDenominator() public view returns (uint256) {
        return IController(controller()).profitSharingDenominator();
    }

    function strategistFeeNumerator() public view returns (uint256) {
        return IController(controller()).strategistFeeNumerator();
    }

    function strategistFeeDenominator() public view returns (uint256) {
        return IController(controller()).strategistFeeDenominator();
    }

    function platformFeeNumerator() public view returns (uint256) {
        return IController(controller()).platformFeeNumerator();
    }

    function platformFeeDenominator() public view returns (uint256) {
        return IController(controller()).platformFeeDenominator();
    }

    function allowedRewardClaimable() public view returns (bool) {
        return getBoolean(_REWARD_CLAIMABLE_SLOT);
    }

    function _setRewardClaimable(bool _value) internal {
        setBoolean(_REWARD_CLAIMABLE_SLOT, _value);
    }

    // ==================== Functionality ====================

    function _notifyProfitInRewardToken(
        address _rewardToken,
        uint256 _rewardBalance
    ) internal {
        if (_rewardBalance > 0) {
            uint256 profitSharingFee = _rewardBalance.mul(profitSharingNumerator()).div(profitSharingDenominator());
            uint256 strategistFee = _rewardBalance.mul(strategistFeeNumerator()).div(strategistFeeDenominator());
            uint256 platformFee = _rewardBalance.mul(platformFeeNumerator()).div(platformFeeDenominator());

            address strategyFeeRecipient = strategist();
            address platformFeeRecipient = IController(controller()).governance();

            emit ProfitLogInReward(
                _rewardToken,
                _rewardBalance,
                profitSharingFee,
                block.timestamp
            );
            emit PlatformFeeLogInReward(
                platformFeeRecipient,
                _rewardToken,
                _rewardBalance,
                platformFee,
                block.timestamp
            );
            emit StrategistFeeLogInReward(
                strategyFeeRecipient,
                _rewardToken,
                _rewardBalance,
                strategistFee,
                block.timestamp
            );

            IERC20(_rewardToken).safeApprove(controller(), 0);
            IERC20(_rewardToken).safeApprove(controller(), profitSharingFee);

            // Distribute/send the fees
            IController(controller()).notifyFee(_rewardToken, profitSharingFee, strategistFee, platformFee);
            IERC20(_rewardToken).safeTransfer(strategyFeeRecipient, strategistFee);
            IERC20(_rewardToken).safeTransfer(platformFeeRecipient, platformFee);
        } else {
            emit ProfitLogInReward(_rewardToken, 0, 0, block.timestamp);
            emit PlatformFeeLogInReward(IController(controller()).governance(), _rewardToken, 0, 0, block.timestamp);
            emit StrategistFeeLogInReward(strategist(), _rewardToken, 0, 0, block.timestamp);
        }
    }

    /**
     * @return the amounts bought back of each buybackToken
     */
    function _notifyProfitAndBuybackInRewardToken(
        address _rewardToken,
        uint256 _rewardBalance,
        address[] memory _buybackTokens
    ) internal returns (uint[] memory) {
        uint[] memory weights = new uint[](_buybackTokens.length);
        for (uint i = 0; i < _buybackTokens.length; i++) {
            weights[i] = 1;
        }

        return _notifyProfitAndBuybackInRewardTokenWithWeights(_rewardToken, _rewardBalance, _buybackTokens, weights);
    }

    /**
     * @param _rewardToken      The reward token to be sold for FARM and _buybackTokens
     * @param _rewardBalance    The amount of `_rewardToken` to be sold for FARM and _buybackTokens
     * @param _buybackTokens    The tokens to be bought for reinvestment
     * @param _weights          the weights to be applied for each buybackToken. For example [100, 300] applies 25% to
     *                          buybackTokens[0] and 75% to buybackTokens[1]
     */
    function _notifyProfitAndBuybackInRewardTokenWithWeights(
        address _rewardToken,
        uint256 _rewardBalance,
        address[] memory _buybackTokens,
        uint[] memory _weights
    ) internal returns (uint[] memory) {
        if (_rewardBalance > 0 && _buybackTokens.length > 0) {
            uint256 profitSharingFee = _rewardBalance.mul(profitSharingNumerator()).div(profitSharingDenominator());
            uint256 strategistFee = _rewardBalance.mul(strategistFeeNumerator()).div(strategistFeeDenominator());
            uint256 platformFee = _rewardBalance.mul(platformFeeNumerator()).div(platformFeeDenominator());
            uint256 buybackAmount = _rewardBalance.sub(profitSharingFee).sub(strategistFee).sub(platformFee);

            emit ProfitAndBuybackLog(_rewardToken, _rewardBalance, profitSharingFee, block.timestamp);

            uint[] memory buybackAmounts = new uint[](_buybackTokens.length);
            {
                uint totalWeight = 0;
                for (uint i = 0; i < _weights.length; i++) {
                    totalWeight += _weights[i];
                }
                require(
                    totalWeight > 0,
                    "totalWeight must be greater than zero"
                );
                for (uint i = 0; i < buybackAmounts.length; i++) {
                    buybackAmounts[i] = buybackAmount.mul(_weights[i]).div(totalWeight);
                }
            }

            emit ProfitAndBuybackLog(
                _rewardToken,
                _rewardBalance,
                profitSharingFee,
                block.timestamp
            );
            emit PlatformFeeLogInReward(
                IController(controller()).governance(),
                _rewardToken,
                _rewardBalance,
                platformFee,
                block.timestamp
            );
            emit StrategistFeeLogInReward(
                strategist(),
                _rewardToken,
                _rewardBalance,
                strategistFee,
                block.timestamp
            );

            address rewardForwarder = IController(controller()).rewardForwarder();
            IERC20(_rewardToken).safeApprove(rewardForwarder, 0);
            IERC20(_rewardToken).safeApprove(rewardForwarder, _rewardBalance);

            // Send and distribute the fees
            IERC20(_rewardToken).safeTransfer(strategist(), strategistFee);
            IERC20(_rewardToken).safeTransfer(IController(controller()).governance(), platformFee);
            return IRewardForwarder(rewardForwarder).notifyFeeAndBuybackAmounts(
                _rewardToken,
                profitSharingFee,
                strategistFee,
                platformFee,
                _buybackTokens,
                buybackAmounts
            );
        } else {
            emit ProfitAndBuybackLog(_rewardToken, 0, 0, block.timestamp);
            emit PlatformFeeLogInReward(IController(controller()).governance(), _rewardToken, 0, 0, block.timestamp);
            emit StrategistFeeLogInReward(strategist(), _rewardToken, 0, 0, block.timestamp);
            return new uint[](_buybackTokens.length);
        }
    }

    // upgradeability

    function _setNextImplementation(address _address) internal {
        setAddress(_NEXT_IMPLEMENTATION_SLOT, _address);
    }

    function nextImplementation() public view returns (address) {
        return getAddress(_NEXT_IMPLEMENTATION_SLOT);
    }

    function _setNextImplementationTimestamp(uint256 _value) internal {
        setUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT, _value);
    }

    function nextImplementationTimestamp() public view returns (uint256) {
        return getUint256(_NEXT_IMPLEMENTATION_TIMESTAMP_SLOT);
    }

    function nextImplementationDelay() public view returns (uint256) {
        return IController(controller()).nextImplementationDelay();
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

    function setUint256Array(bytes32 slot, uint256[] memory _values) internal {
        // solhint-disable-next-line no-inline-assembly
        setUint256(slot, _values.length);
        for (uint i = 0; i < _values.length; i++) {
            setUint256(bytes32(uint(slot) + 1 + i), _values[i]);
        }
    }

    function setAddressArray(bytes32 slot, address[] memory _values) internal {
        // solhint-disable-next-line no-inline-assembly
        setUint256(slot, _values.length);
        for (uint i = 0; i < _values.length; i++) {
            setAddress(bytes32(uint(slot) + 1 + i), _values[i]);
        }
    }

    function getUint256Array(bytes32 slot) internal view returns (uint[] memory values) {
        // solhint-disable-next-line no-inline-assembly
        values = new uint[](getUint256(slot));
        for (uint i = 0; i < values.length; i++) {
            values[i] = getUint256(bytes32(uint(slot) + 1 + i));
        }
    }

    function getAddressArray(bytes32 slot) internal view returns (address[] memory values) {
        // solhint-disable-next-line no-inline-assembly
        values = new address[](getUint256(slot));
        for (uint i = 0; i < values.length; i++) {
            values[i] = getAddress(bytes32(uint(slot) + 1 + i));
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
}
