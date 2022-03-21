pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/uniswap/IUniswapV2Router02.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IPotPool.sol";
import "../interfaces/IVault.sol";
import "../upgradability/BaseUpgradeableStrategy.sol";
import "./interfaces/IMasterChef.sol";
import "../interfaces/uniswap/IUniswapV2Pair.sol";


contract MasterChefStrategyWithBuyback is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _POOL_ID_SLOT = 0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;

    constructor() public BaseUpgradeableStrategy() {
        assert(_POOL_ID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolId")) - 1));
    }

    function initializeBaseStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address[] memory _rewardTokens,
        address _strategist,
        uint256 _poolID
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens,
            _strategist
        );

        address _lpt;
        (_lpt,,,) = IMasterChef(rewardPool()).poolInfo(_poolID);
        require(_lpt == underlying(), "Pool Info does not match underlying");
        _setPoolId(_poolID);
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function rewardPoolBalance() internal view returns (uint256 bal) {
        (bal,) = IMasterChef(rewardPool()).userInfo(poolId(), address(this));
    }

    function exitRewardPool() internal {
        uint256 bal = rewardPoolBalance();
        if (bal != 0) {
            IMasterChef(rewardPool()).withdraw(poolId(), bal);
        }
    }

    function emergencyExitRewardPool() internal {
        uint256 bal = rewardPoolBalance();
        if (bal != 0) {
            IMasterChef(rewardPool()).emergencyWithdraw(poolId());
        }
    }

    function _enterRewardPool() internal {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
        IERC20(underlying()).safeApprove(rewardPool(), 0);
        IERC20(underlying()).safeApprove(rewardPool(), entireBalance);
        IMasterChef(rewardPool()).deposit(poolId(), entireBalance);
    }

    function emergencyExit() public onlyGovernance {
        emergencyExitRewardPool();
        _setPausedInvesting(true);
    }

    /**
     *   Resumes the ability to invest into the underlying reward pools
     */
    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    // We assume that all the tradings can be done on Uniswap
    function _liquidateReward() internal {
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            uint256 rewardBalance = IERC20(_rewardTokens[i]).balanceOf(address(this));
            if (rewardBalance < sellFloor()) {
                // Profits can be disabled for possible simplified and rapid exit
                emit ProfitsNotCollected(_rewardTokens[i], sell(), rewardBalance < sellFloor());
                return;
            }

            address[] memory outputTokens = new address[](2);
            outputTokens[0] = IUniswapV2Pair(underlying()).token0();
            outputTokens[1] = IUniswapV2Pair(underlying()).token1();

            uint[] memory amounts = _notifyProfitAndBuybackInRewardToken(
                _rewardTokens[i],
                rewardBalance,
                outputTokens
            );

            // the returned added liquidity is invested via the call to `investAllUnderlying`
            IUniswapV2Router02(SUSHI_ROUTER).addLiquidity(
                outputTokens[0],
                outputTokens[1],
                amounts[0],
                amounts[1],
                1, // we are willing to take whatever the pair gives us
                1, // we are willing to take whatever the pair gives us
                address(this),
                block.timestamp
            );
        }
    }

    /**
     * Stakes everything the strategy holds into the reward pool
     */
    function investAllUnderlying() internal onlyNotPausedInvesting {
        // this check is needed, because most of the SNX reward pools will revert if
        // you try to stake(0).
        if (IERC20(underlying()).balanceOf(address(this)) > 0) {
            _enterRewardPool();
        }
    }

    /**
     * Withdraws all the asset to the vault
     */
    function withdrawAllToVault() public restricted {
        if (address(rewardPool()) != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    /**
     * Withdraws all the asset to the vault
     */
    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > entireBalance) {
            // While we have the check above, we still using SafeMath below
            // for the peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(entireBalance);
            uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
            IMasterChef(rewardPool()).withdraw(poolId(), toWithdraw);
        }

        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    /**
     * Note that we currently do not have a mechanism here to include the amount of reward that is accrued.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        if (rewardPool() == address(0)) {
            return IERC20(underlying()).balanceOf(address(this));
        }
        // Adding the amount locked in the reward pool and the amount that is somehow in this contract
        // both are in the units of "underlying"
        // The second part is needed because there is the emergency exit mechanism
        // which would break the assumption that all the funds are always inside of the reward pool
        return rewardPoolBalance().add(IERC20(underlying()).balanceOf(address(this)));
    }

    function doHardWork() external onlyNotPausedInvesting restricted {
        exitRewardPool();
        _liquidateReward();
        investAllUnderlying();
    }

    function _getReward() internal {
        exitRewardPool();
        investAllUnderlying();
    }

    function _setPoolId(uint256 _value) internal {
        setUint256(_POOL_ID_SLOT, _value);
    }

    function poolId() public view returns (uint256) {
        return getUint256(_POOL_ID_SLOT);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
    }
}
