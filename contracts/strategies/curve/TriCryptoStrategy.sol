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
        address _crvDepositPool,
        address _crvDepositToken,
        uint256 _depositArrayPosition
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens
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
        return (isRewardToken(token) || token == underlying());
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
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            if (!sell()) {
                // Profits can be disabled for possible simplified exit
                emit ProfitsNotCollected(_rewardTokens[i], sell(), false);
                return;
            }

            uint256 rewardBalance = IERC20(_rewardTokens[i]).balanceOf(address(this));
            address[] memory buybackTokens = new address[](1);
            buybackTokens[0] = depositToken();

            _notifyProfitAndBuybackInRewardToken(_rewardTokens[i], rewardBalance, buybackTokens);

            uint256 tokenBalance = IERC20(depositToken()).balanceOf(address(this));
            if (tokenBalance > 0) {
                depositIntoTriCrypto();
            }
        }
    }

    function depositIntoTriCrypto() internal {
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


    function _setDepositToken(address _address) internal {
        setAddress(_DEPOSIT_TOKEN_SLOT, _address);
    }

    function depositToken() public view returns (address) {
        return getAddress(_DEPOSIT_TOKEN_SLOT);
    }

    function _setDepositArrayPosition(uint256 _value) internal {
        setUint256(_DEPOSIT_ARRAY_POSITION_SLOT, _value);
    }

    function depositArrayPosition() public view returns (uint256) {
        return getUint256(_DEPOSIT_ARRAY_POSITION_SLOT);
    }

    function _setCurveDepositPool(address _address) internal {
        setAddress(_CRV_DEPOSIT_POOL_SLOT, _address);
    }

    function curveDeposit() public view returns (address) {
        return getAddress(_CRV_DEPOSIT_POOL_SLOT);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
    }
}
