pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "../../base/interfaces/IStrategy.sol";
import "../../base/interfaces/curve/IGauge.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";

import "./interfaces/IStargateFarmingPool.sol";
import "./interfaces/IStargateRouter.sol";
import "./interfaces/IStargateToken.sol";


contract StargateStrategy is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _DEPOSIT_TOKEN_SLOT = 0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;
    bytes32 internal constant _STARGATE_ROUTER_SLOT = 0x50cf24350c52fb388d41633efadcddb2fcfdac560121bd804c614894e1344423;
    bytes32 internal constant _STARGATE_POOL_ID_SLOT = 0xdde5da573f4abb9d5adeea4ab5f76d1ae01e04e01a2bfcb11322b4001c69c146;
    bytes32 internal constant _STARGATE_REWARD_PID_SLOT = 0x893cb48ac83aa0075866e20e9a91e0211aed1b871dfb764e3a6054cd6082714e;

    constructor() public BaseUpgradeableStrategy() {
        assert(_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositToken")) - 1));
        assert(_STARGATE_ROUTER_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.stargateRouter")) - 1));
        assert(_STARGATE_POOL_ID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.stargatePoolId")) - 1));
        assert(_STARGATE_REWARD_PID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.stargateRewardPid")) - 1));
    }

    function initializeStargateStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address[] memory _rewardTokens,
        address _strategist,
        address _depositToken,
        address _stargateRouter,
        uint256 _stargatePoolId,
        uint256 _stargateRewardPid
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
            IStargateToken(_underlying).token() == _depositToken,
            "underlying does not match deposit token"
        );
        require(
            IStargateToken(_underlying).poolId() == _stargatePoolId,
            "underlying does not match pool ID"
        );

        (address foundLpToken, , , ) = IStargateFarmingPool(_rewardPool).poolInfo(_stargateRewardPid);
        require(
            foundLpToken == _underlying,
            "reward pool LP token does not match underlying"
        );

        _setDepositToken(_depositToken);
        _setStargateRouter(_stargateRouter);
        _setStargatePoolId(_stargatePoolId);
        _setStargateRewardPid(_stargateRewardPid);
    }

    function depositArbCheck() external view returns(bool) {
        return true;
    }

    function depositToken() public view returns (address) {
        return getAddress(_DEPOSIT_TOKEN_SLOT);
    }

    function stargateRouter() public view returns (address) {
        return getAddress(_STARGATE_ROUTER_SLOT);
    }

    function stargatePoolId() public view returns (uint256) {
        return getUint256(_STARGATE_POOL_ID_SLOT);
    }

    function stargateRewardPid() public view returns (uint256) {
        return getUint256(_STARGATE_REWARD_PID_SLOT);
    }

    function getRewardPoolValues() public returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = IStargateFarmingPool(rewardPool()).pendingStargate(stargateRewardPid(), address(this));
    }

    // ========================= Internal Functions =========================

    function _setDepositToken(address _depositToken) internal {
        setAddress(_DEPOSIT_TOKEN_SLOT, _depositToken);
    }

    function _setStargatePoolId(uint256 _stargatePoolId) internal {
        setUint256(_STARGATE_POOL_ID_SLOT, _stargatePoolId);
    }

    function _setStargateRewardPid(uint256 _stargateRewardPid) internal {
        setUint256(_STARGATE_REWARD_PID_SLOT, _stargateRewardPid);
    }

    function _setStargateRouter(address _stargateRouter) internal {
        setAddress(_STARGATE_ROUTER_SLOT, _stargateRouter);
    }

    function _finalizeUpgrade() internal {}

    function _rewardPoolBalance() internal view returns (uint256) {
        (uint balance,) = IStargateFarmingPool(rewardPool()).userInfo(stargateRewardPid(), address(this));
        return balance;
    }

    function _partialExitRewardPool(uint256 _amount) internal {
        if (_amount > 0) {
            IStargateFarmingPool(rewardPool()).withdraw(stargateRewardPid(), _amount);
        }
    }

    function _enterRewardPool() internal {
        address _underlying = underlying();
        address _rewardPool = rewardPool();

        uint256 entireBalance = IERC20(_underlying).balanceOf(address(this));
        IERC20(_underlying).safeApprove(_rewardPool, 0);
        IERC20(_underlying).safeApprove(_rewardPool, entireBalance);
        IStargateFarmingPool(_rewardPool).deposit(stargateRewardPid(), entireBalance); // deposit and stake
    }

    function _claimRewards() internal {
        // claiming is done by depositing 0 into the pool
        IStargateFarmingPool(rewardPool()).deposit(stargateRewardPid(), 0);
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
        address _router = stargateRouter();
        uint256 tokenBalance = IERC20(_depositToken).balanceOf(address(this));
        IERC20(_depositToken).safeApprove(_router, 0);
        IERC20(_depositToken).safeApprove(_router, tokenBalance);

        IStargateRouter(_router).addLiquidity(stargatePoolId(), tokenBalance, address(this));
    }
}
