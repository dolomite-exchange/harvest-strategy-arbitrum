pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "../inheritance/Constants.sol";
import "../inheritance/ControllableInit.sol";
import "../interfaces/IController.sol";
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

    // ========================= Private Functions =========================

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
