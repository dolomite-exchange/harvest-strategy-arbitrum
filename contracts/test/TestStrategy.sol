pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../base/upgradability/BaseUpgradeableStrategy.sol";
import "./TestRewardPool.sol";


/**
 * A test implementation of `BaseUpgradeableStrategy` for running unit tests. This strategy receives USDC, holds it
 * in this contract, and sells it to WETH. It's not much, but it's honest work
 */
contract TestStrategy is BaseUpgradeableStrategy {
    using SafeERC20 for IERC20;

    function initializeBaseStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address[] memory _rewardTokens,
        address _strategist
    ) public initializer {
        require(
            _rewardTokens.length == 1,
            "_rewardTokens must have length of 1"
        );
        require(
            TestRewardPool(_rewardPool).depositToken() == _underlying,
            "_rewardPool::depositToken must eq _underlying"
        );
        require(
            TestRewardPool(_rewardPool).rewardToken() == _rewardTokens[0],
            "_rewardPool::rewardToken must eq _rewardTokens[0]"
        );

        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens,
            _strategist
        );
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function _finalizeUpgrade() internal {}

    function _claimRewards() internal {
        TestRewardPool(rewardPool()).claimRewards();
    }

    function _rewardPoolBalance() internal view returns (uint) {
        return IERC20(underlying()).balanceOf(rewardPool());
    }

    function _liquidateReward() internal {
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            uint256 rewardBalance = IERC20(_rewardTokens[i]).balanceOf(address(this));
            address[] memory buybackTokens = new address[](1);
            buybackTokens[0] = underlying();

            _notifyProfitAndBuybackInRewardToken(
                _rewardTokens[i],
                rewardBalance,
                buybackTokens
            );

            uint256 tokenBalance = IERC20(buybackTokens[0]).balanceOf(address(this));
            if (tokenBalance > 0) {
                _enterRewardPool();
            }
        }
    }

    function _partialExitRewardPool(uint256 _amount) internal {
        TestRewardPool(rewardPool()).withdrawFromPool(_amount);
    }

    function _enterRewardPool() internal {
        address _underlying = underlying();
        address _rewardPool = rewardPool();
        uint amount = IERC20(_underlying).balanceOf(address(this));

        IERC20(_underlying).safeApprove(_rewardPool, 0);
        IERC20(_underlying).safeApprove(_rewardPool, amount);
        TestRewardPool(_rewardPool).depositIntoPool(amount);
    }
}
