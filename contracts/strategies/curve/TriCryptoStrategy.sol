pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "../../base/interfaces/IStrategy.sol";
import "../../base/interfaces/curve/IGauge.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";

import "./interfaces/ITriCryptoPool.sol";


contract TriCryptoStrategy is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _DEPOSIT_TOKEN_SLOT = 0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;
    bytes32 internal constant _DEPOSIT_ARRAY_POSITION_SLOT = 0xb7c50ef998211fff3420379d0bf5b8dfb0cee909d1b7d9e517f311c104675b09;
    bytes32 internal constant _CRV_DEPOSIT_POOL_SLOT = 0xa8dfe2f08f0de0508bc25f877914a259758f1ca3752cae910ab0fd5bf4a2f1a1;

    constructor() public BaseUpgradeableStrategy() {
        assert(_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositToken")) - 1));
        assert(_DEPOSIT_ARRAY_POSITION_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositArrayPosition")) - 1));
        assert(_CRV_DEPOSIT_POOL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.crvDepositPool")) - 1));
    }

    function initializeBaseStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address[] memory _rewardTokens,
        address _strategist,
        address _crvDepositPool,
        address _crvDepositToken,
        uint256 _depositArrayPosition
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens,
            _strategist
        );

        require(
            IGauge(rewardPool()).lp_token() == underlying(),
            "pool lpToken does not match underlying"
        );
        require(
            ITriCryptoPool(_crvDepositPool).coins(_depositArrayPosition) == _crvDepositToken,
            "pool lpToken does not match underlying"
        );

        _setCurveDepositPool(_crvDepositPool);
        _setDepositToken(_crvDepositToken);
        _setDepositArrayPosition(_depositArrayPosition);
    }

    function depositArbCheck() external view returns(bool) {
        return true;
    }

    function depositToken() public view returns (address) {
        return getAddress(_DEPOSIT_TOKEN_SLOT);
    }

    function curveDeposit() public view returns (address) {
        return getAddress(_CRV_DEPOSIT_POOL_SLOT);
    }

    function depositArrayPosition() public view returns (uint256) {
        return getUint256(_DEPOSIT_ARRAY_POSITION_SLOT);
    }

    function getRewardPoolValues() public returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = IGauge(rewardPool()).claimable_reward_write(address(this), rewardTokens()[0]);
    }

    // ========================= Internal Functions =========================

    function _setDepositToken(address _address) internal {
        setAddress(_DEPOSIT_TOKEN_SLOT, _address);
    }

    function _setDepositArrayPosition(uint256 _value) internal {
        setUint256(_DEPOSIT_ARRAY_POSITION_SLOT, _value);
    }

    function _setCurveDepositPool(address _address) internal {
        setAddress(_CRV_DEPOSIT_POOL_SLOT, _address);
    }

    function _finalizeUpgrade() internal {}

    function _rewardPoolBalance() internal view returns (uint256) {
        return IGauge(rewardPool()).balanceOf(address(this));
    }

    function _partialExitRewardPool(uint256 _amount) internal {
        if (_amount > 0) {
            IGauge(rewardPool()).withdraw(_amount);
        }
    }

    function _enterRewardPool() internal {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
        IERC20(underlying()).safeApprove(rewardPool(), 0);
        IERC20(underlying()).safeApprove(rewardPool(), entireBalance);
        IGauge(rewardPool()).deposit(entireBalance); // deposit and stake
    }

    function _claimRewards() internal {
        IGauge(rewardPool()).claim_rewards();
    }

    function _liquidateReward() internal {
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            uint256 rewardBalance = IERC20(_rewardTokens[i]).balanceOf(address(this));
            address[] memory buybackTokens = new address[](1);
            buybackTokens[0] = depositToken();

            _notifyProfitAndBuybackInRewardToken(_rewardTokens[i], rewardBalance, buybackTokens);

            uint256 tokenBalance = IERC20(depositToken()).balanceOf(address(this));
            if (tokenBalance > 0) {
                _mintLiquidityTokens();
                _enterRewardPool();
            }
        }
    }

    function _mintLiquidityTokens() internal {
        address _depositToken = depositToken();
        uint256 tokenBalance = IERC20(_depositToken).balanceOf(address(this));
        IERC20(_depositToken).safeApprove(curveDeposit(), 0);
        IERC20(_depositToken).safeApprove(curveDeposit(), tokenBalance);

        uint256[3] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;

        // we can accept 0 as minimum, this will be called only by trusted roles
        uint256 minimum = 0;
        ITriCryptoPool(curveDeposit()).add_liquidity(depositArray, minimum);
    }
}
