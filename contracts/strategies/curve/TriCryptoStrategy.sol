pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interfaces/IStrategy.sol";
import "../../base/interfaces/curve/IGauge.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";

import "./interfaces/ITriCryptoPool.sol";


contract TriCryptoStrategy is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant POOL = CRV_TRI_CRYPTO_POOL;
    address public constant BUYBACK_TOKEN = WETH;
    uint256 public constant DEPOSIT_ARRAY_POSITION = 2;

    constructor() public BaseUpgradeableStrategy() {
    }

    function initializeBaseStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _rewardToken
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardToken
        );

        require(IGauge(rewardPool()).lp_token() == underlying(), "pool lpToken does not match underlying");
    }

    function depositArbCheck() public view returns(bool) {
        return true;
    }

    function rewardPoolBalance() internal view returns (uint256) {
        return IGauge(rewardPool()).balanceOf(address(this));
    }

    function exitRewardPool() internal {
        uint256 stakedBalance = rewardPoolBalance();
        if (stakedBalance != 0) {
            IGauge(rewardPool()).withdraw(stakedBalance);
        }
    }

    function partialWithdrawalRewardPool(uint256 amount) internal {
        IGauge(rewardPool()).withdraw(amount);  // don't claim rewards at this point
    }

    function emergencyExitRewardPool() internal {
        uint256 stakedBalance = rewardPoolBalance();
        if (stakedBalance != 0) {
            IGauge(rewardPool()).withdraw(stakedBalance); // don't claim rewards
        }
    }

    function isUnsalvageableToken(address token) public view returns (bool) {
        return (token == rewardToken() || token == underlying());
    }

    function enterRewardPool() internal {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
        IERC20(underlying()).safeApprove(rewardPool(), 0);
        IERC20(underlying()).safeApprove(rewardPool(), entireBalance);
        IGauge(rewardPool()).deposit(entireBalance); // deposit and stake
    }

    /*
    *   In case there are some issues discovered about the pool or underlying asset
    *   Governance can exit the pool properly
    *   The function is only used for emergency to exit the pool
    */
    function emergencyExit() public onlyGovernance {
        emergencyExitRewardPool();
        _setPausedInvesting(true);
    }

    /*
    *   Resumes the ability to invest into the underlying reward pools
    */

    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    function _liquidateReward() internal {
        if (!sell()) {
            // Profits can be disabled for possible simplified exit
            emit ProfitsNotCollected(sell(), false);
            return;
        }

        uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
        address[] memory buybackTokens = new address[](1);
        buybackTokens[0] = BUYBACK_TOKEN;

        _notifyProfitAndBuybackInRewardToken(rewardBalance, buybackTokens);

        uint256 tokenBalance = IERC20(BUYBACK_TOKEN).balanceOf(address(this));
        if (tokenBalance > 0) {
            depositIntoTriCrypto();
        }
    }

    function depositIntoTriCrypto() internal {
        uint256 tokenBalance = IERC20(BUYBACK_TOKEN).balanceOf(address(this));
        IERC20(BUYBACK_TOKEN).safeApprove(POOL, 0);
        IERC20(BUYBACK_TOKEN).safeApprove(POOL, tokenBalance);

        uint256[3] memory depositArray;
        depositArray[DEPOSIT_ARRAY_POSITION] = tokenBalance;

        // we can accept 0 as minimum, this will be called only by trusted roles
        uint256 minimum = 0;
        ITriCryptoPool(POOL).add_liquidity(depositArray, minimum);
    }


    /*
    *   Stakes everything the strategy holds into the reward pool
    */
    function investAllUnderlying() internal onlyNotPausedInvesting {
        // this check is needed, because most of the SNX reward pools will revert if you try to stake(0).
        if(IERC20(underlying()).balanceOf(address(this)) > 0) {
            enterRewardPool();
        }
    }

    /**
     * Withdraws all of the assets to the vault
     */
    function withdrawAllToVault() public restricted {
        if (address(rewardPool()) != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    /**
     * Withdraws `amount` of assets to the vault
     */
    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if(amount > entireBalance){
            // While we have the check above, we still using SafeMath below
            // for the peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(entireBalance);
            uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
            partialWithdrawalRewardPool(toWithdraw);
        }
        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    /**
     * @notice We currently do not have a mechanism here to include the amount of reward that is accrued.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        return rewardPoolBalance()
        .add(IERC20(underlying()).balanceOf(address(this)));
    }

    /**
     * It's not much, but it's honest work.
     */
    function doHardWork() external onlyNotPausedInvesting restricted {
        IGauge(rewardPool()).claim_rewards();
        _liquidateReward();
        investAllUnderlying();
    }

    /**
    * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
    * simplest possible way.
    */
    function setSell(bool s) public onlyGovernance {
        _setSell(s);
    }

    /**
    * Sets the minimum amount of CRV needed to trigger a sale.
    */
    function setSellFloor(uint256 floor) public onlyGovernance {
        _setSellFloor(floor);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
    }
}
