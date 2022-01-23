pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../inheritance/ControllableInit.sol";
import "../interface/IController.sol";
import "../interface/IFeeRewardForwarder.sol";
import "./BaseUpgradeableStrategy.sol";


contract BaseUpgradeableStrategyClaimable is BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier restricted() {
        require(msg.sender == vault() || msg.sender == controller()
            || msg.sender == governance(),
            "The sender has to be the controller, governance, or vault");
        _;
    }

    // This is only used in `investAllUnderlying()`
    // The user can still freely withdraw from the strategy
    modifier onlyNotPausedInvesting() {
        require(!pausedInvesting(), "Action blocked as the strategy is in emergency state");
        _;
    }

    modifier onlyMultiSigOrGovernance() {
        require(msg.sender == multiSig() || msg.sender == governance(), "The sender has to be multiSig or governance");
        _;
    }

    constructor() public BaseUpgradeableStrategyStorage() {
    }

    function initialize(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _rewardToken,
        uint256 _profitSharingNumerator,
        uint256 _profitSharingDenominator,
        bool _sell,
        uint256 _sellFloor
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardToken,
            _profitSharingNumerator,
            _profitSharingDenominator,
            _sell,
            _sellFloor
        );

        _setMultiSig(DEFAULT_MULTI_SIG_ADDRESS);
    }

    // change multiSig
    function setMultiSig(address _address) public onlyGovernance {
        _setMultiSig(_address);
    }

    // reward claiming by multiSig
    function claimReward() public onlyMultiSigOrGovernance {
        require(allowedRewardClaimable(), "reward claimable is not allowed");
        _getReward();
        uint256 rewardBalance = IERC20(rewardToken()).balanceOf(address(this));
        IERC20(rewardToken()).safeTransfer(msg.sender, rewardBalance);
    }

    function setRewardClaimable(bool flag) public onlyGovernance {
        _setRewardClaimable(flag);
    }

    /**
     * If there are multiple reward tokens, they should all be liquidated to rewardToken.
     */
    function _getReward() internal;

}
