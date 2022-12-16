pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "../inheritance/Constants.sol";
import "../inheritance/ControllableInit.sol";
import "../interfaces/IController.sol";
import "../interfaces/IVault.sol";
import "./BaseUpgradeableStrategyStorage.sol";
import "../interfaces/IStrategy.sol";


contract BaseUpgradeableStrategy is
    IStrategy,
    Initializable,
    ControllableInit,
    BaseUpgradeableStrategyStorage,
    Constants
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ==================== Modifiers ====================

    modifier restricted() {
        require(msg.sender == vault() || msg.sender == controller() || msg.sender == governance(),
            "The sender has to be the controller, governance, or vault");
        _;
    }

    /**
     * @dev This is only used in `investAllUnderlying()`. The user can still freely withdraw from the strategy
     */
    modifier onlyNotPausedInvesting() {
        require(!pausedInvesting(), "Action blocked as the strategy is in emergency state");
        _;
    }

    constructor() public BaseUpgradeableStrategyStorage() {
    }

    // ==================== Functions ====================

    function initialize(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address[] memory _rewardTokens,
        address _strategist
    ) public initializer {
        require(
            IVault(_vault).underlying() == _underlying,
            "underlying does not match vault underlying"
        );

        ControllableInit.initialize(_storage);
        _setUnderlying(_underlying);
        _setVault(_vault);
        _setRewardPool(_rewardPool);
        _setRewardTokens(_rewardTokens);
        _setStrategist(_strategist);
        _setSell(true);
        _setSellFloor(0);
        _setPausedInvesting(false);
    }

    /**
    * Schedules an upgrade for this vault's proxy.
    */
    function scheduleUpgrade(address _nextImplementation) public onlyGovernance {
        uint nextImplementationTimestamp = block.timestamp.add(nextImplementationDelay());
        _setNextImplementation(_nextImplementation);
        _setNextImplementationTimestamp(nextImplementationTimestamp);
        emit UpgradeScheduled(_nextImplementation, nextImplementationTimestamp);
    }

    function shouldUpgrade() public view returns (bool, address) {
        return (
            nextImplementationTimestamp() != 0
            && block.timestamp > nextImplementationTimestamp()
            && nextImplementation() != address(0),
            nextImplementation()
        );
    }

    /**
     * Governance or Controller can claim coins that are somehow transferred into the contract. Note that they cannot
     * come in take away coins that are used and defined in the strategy itself. Those are protected by the
     * `isUnsalvageableToken` function. To check, see where those are being flagged.
     */
    function salvageToken(
        address _recipient,
        address _token,
        uint256 _amount
    )
    public
    onlyControllerOrGovernance
    nonReentrant {
        // To make sure that governance cannot come in and take away the coins
        require(!isUnsalvageableToken(_token), "The token must be salvageable");
        IERC20(_token).safeTransfer(_recipient, _amount);
    }

    function isUnsalvageableToken(address _token) public view returns (bool) {
        return (isRewardToken(_token) || _token == underlying());
    }

    function setStrategist(address _strategist) external {
        require(msg.sender == strategist(), "Sender must be strategist");
        require(_strategist != address(0) && _strategist != address(this), "Invalid strategist");
        _setStrategist(_strategist);
    }

    function setSell(bool _isSellAllowed) public onlyGovernance {
        _setSell(_isSellAllowed);
    }

    function setSellFloor(uint256 _sellFloor) public onlyGovernance {
        _setSellFloor(_sellFloor);
    }

    /**
     *  In case there are some issues discovered about the pool or underlying asset, Governance can exit the pool
     * quickly.
     */
    function emergencyExit() external onlyGovernance nonReentrant {
        _partialExitRewardPool(_rewardPoolBalance());
        IERC20(underlying()).safeTransfer(governance(), IERC20(underlying()).balanceOf(address(this)));
        _setPausedInvesting(true);
    }

    /**
     *   Resumes the ability to invest into the underlying reward pools
     */
    function continueInvesting() external onlyGovernance {
        _setPausedInvesting(false);
    }

    /**
     * @notice We currently do not have a mechanism here to include the amount of reward that is accrued.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        return _rewardPoolBalance().add(IERC20(underlying()).balanceOf(address(this)));
    }

    /**
     * It's not much, but it's honest work.
     */
    function doHardWork() external onlyNotPausedInvesting restricted nonReentrant {
        _claimRewards();
        _liquidateReward();
        _enterRewardPool();
    }

    function enterRewardPool() external onlyNotPausedInvesting restricted nonReentrant {
        _enterRewardPool();
    }

    /**
     * Withdraws all of the assets to the vault
     */
    function withdrawAllToVault() external restricted nonReentrant {
        if (address(rewardPool()) != address(0)) {
            _partialExitRewardPool(_rewardPoolBalance());
        }
        _liquidateReward();
        IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    /**
     * Withdraws `amount` of assets to the vault
     */
    function withdrawToVault(uint256 amount) external restricted nonReentrant {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > entireBalance) {
            // While we have the check above, we still using SafeMath below for the peace of mind (in case something
            // gets changed in between)
            uint256 needToWithdraw = amount.sub(entireBalance);
            uint256 toWithdraw = Math.min(_rewardPoolBalance(), needToWithdraw);
            _partialExitRewardPool(toWithdraw);
        }
        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    function finalizeUpgrade() external onlyGovernance nonReentrant {
        _finalizeUpgradePrivate();
        _finalizeUpgrade();
    }

    // ========================= Internal & Private Functions =========================

    // ==================== Functionality ====================

    /**
     * @dev Same as `_notifyProfitAndBuybackInRewardToken` but does not perform a compounding buyback. Just takes fees
     *      instead.
     */
    function _notifyProfitInRewardToken(
        address _rewardToken,
        uint256 _rewardBalance
    ) internal {
        uint denominator = profitSharingNumerator().add(strategistFeeNumerator()).add(platformFeeNumerator());
        if (_rewardBalance > 0 && denominator > 0) {
            require(
                profitSharingDenominator() == strategistFeeDenominator(),
                "profit sharing denominator must match strategist fee denominator"
            );
            require(
                strategistFeeDenominator() == platformFeeDenominator(),
                "strategist fee denominator must match platform fee denominator"
            );

            uint256 strategistFee = _rewardBalance.mul(strategistFeeNumerator()).div(denominator);
            uint256 platformFee = _rewardBalance.mul(platformFeeNumerator()).div(denominator);
            // profitSharingFee gets what's left, so there's no dust left in the contract from truncation
            uint256 profitSharingFee = _rewardBalance.sub(strategistFee).sub(platformFee);

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

            address rewardForwarder = IController(controller()).rewardForwarder();
            IERC20(_rewardToken).safeApprove(rewardForwarder, 0);
            IERC20(_rewardToken).safeApprove(rewardForwarder, _rewardBalance);

            // Distribute/send the fees
            IRewardForwarder(rewardForwarder).notifyFee(
                _rewardToken,
                profitSharingFee,
                strategistFee,
                platformFee
            );
        } else {
            emit ProfitLogInReward(_rewardToken, 0, 0, block.timestamp);
            emit PlatformFeeLogInReward(IController(controller()).governance(), _rewardToken, 0, 0, block.timestamp);
            emit StrategistFeeLogInReward(strategist(), _rewardToken, 0, 0, block.timestamp);
        }
    }

    /**
     * @param _rewardToken      The token that will be sold into `_buybackTokens`
     * @param _rewardBalance    The amount of `_rewardToken` to be sold into `_buybackTokens`
     * @param _buybackTokens    The tokens to be bought back by the protocol and sent back to this strategy contract.
     *                          Calling this function automatically sends the appropriate amounts to the strategist,
     *                          profit share and platform
     * @return The amounts bought back of each buyback token. Each index in the array corresponds with `_buybackTokens`.
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
     * @param _rewardToken      The token that will be sold into `_buybackTokens`
     * @param _rewardBalance    The amount of `_rewardToken` to be sold into `_buybackTokens`
     * @param _buybackTokens    The tokens to be bought back by the protocol and sent back to this strategy contract.
     *                          Calling this function automatically sends the appropriate amounts to the strategist,
     *                          profit share and platform
     * @param _weights          The weights to be applied for each buybackToken. For example [100, 300] applies 25% to
     *                          buybackTokens[0] and 75% to buybackTokens[1]
     * @return The amounts bought back of each buyback token. Each index in the array corresponds with `_buybackTokens`.
     */
    function _notifyProfitAndBuybackInRewardTokenWithWeights(
        address _rewardToken,
        uint256 _rewardBalance,
        address[] memory _buybackTokens,
        uint[] memory _weights
    ) internal returns (uint[] memory) {
        address governance = IController(controller()).governance();

        if (_rewardBalance > 0 && _buybackTokens.length > 0) {
            uint256 profitSharingFee = _rewardBalance.mul(profitSharingNumerator()).div(profitSharingDenominator());
            uint256 strategistFee = _rewardBalance.mul(strategistFeeNumerator()).div(strategistFeeDenominator());
            uint256 platformFee = _rewardBalance.mul(platformFeeNumerator()).div(platformFeeDenominator());
            // buybackAmount is set to what's left, which results in leaving no dust in this contract
            uint256 buybackAmount = _rewardBalance.sub(profitSharingFee).sub(strategistFee).sub(platformFee);

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
                governance,
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
            emit PlatformFeeLogInReward(governance, _rewardToken, 0, 0, block.timestamp);
            emit StrategistFeeLogInReward(strategist(), _rewardToken, 0, 0, block.timestamp);
            return new uint[](_buybackTokens.length);
        }
    }

    function _finalizeUpgradePrivate() private {
        _setNextImplementation(address(0));
        _setNextImplementationTimestamp(0);
    }

    // ========================= Abstract Internal Functions =========================

    /**
     * @dev Called after the upgrade is finalized and `nextImplementation` is set back to null. This function is called
     *      for the sake of clean up, so any new state that needs to be set can be done.
     */
    function _finalizeUpgrade() internal;

    /**
     * @dev Withdraws all earned rewards from the reward pool(s)
     */
    function _claimRewards() internal;

    /**
     * @return The balance of `underlying()` in `rewardPool()`
     */
    function _rewardPoolBalance() internal view returns (uint);

    /**
     * @dev Liquidates reward tokens for `underlying`
     */
    function _liquidateReward() internal;

    /**
     * @dev Withdraws `_amount` of `underlying()` from the `rewardPool()` to this contract. Does not attempt to claim
     *      any rewards
     */
    function _partialExitRewardPool(uint256 _amount) internal;

    /**
     * @dev Deposits underlying token into the yield-earning contract.
     */
    function _enterRewardPool() internal;
}
