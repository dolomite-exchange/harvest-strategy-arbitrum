pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "../inheritance/Constants.sol";
import "../inheritance/ControllableInit.sol";
import "../interfaces/IController.sol";
import "./BaseUpgradeableStrategyStorage.sol";
import "../interfaces/IStrategy.sol";


contract BaseUpgradeableStrategy
    is IStrategy, Initializable, ControllableInit, BaseUpgradeableStrategyStorage, Constants {
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
    function scheduleUpgrade(address impl) public onlyGovernance {
        _setNextImplementation(impl);
        _setNextImplementationTimestamp(block.timestamp.add(nextImplementationDelay()));
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
        address recipient,
        address token,
        uint256 amount
    ) public onlyControllerOrGovernance {
        // To make sure that governance cannot come in and take away the coins
        require(!isUnsalvageableToken(token), "token is defined as not salvageable");
        IERC20(token).safeTransfer(recipient, amount);
    }

    function setStrategist(address _strategist) external {
        require(msg.sender == strategist(), "invalid sender");
        require(_strategist != address(0) && _strategist != address(this), "invalid strategist");
        _setStrategist(_strategist);
    }

    function _finalizeUpgrade() internal {
        _setNextImplementation(address(0));
        _setNextImplementationTimestamp(0);
    }
}
