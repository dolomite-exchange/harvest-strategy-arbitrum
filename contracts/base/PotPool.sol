// SPDX-License-Identifier: MIT
pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

import "./inheritance/Controllable.sol";
import "./interface/IController.sol";
import "./interface/IPotPool.sol";

import "./MultipleRewardDistributionRecipient.sol";

contract PotPool is MultipleRewardDistributionRecipient, Controllable, ERC20, ERC20Detailed, IPotPool {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public lpToken;
    uint256 public duration; // making it not a constant is less gas efficient, but portable

    mapping(address => uint256) public stakedBalanceOf;

    mapping(address => bool) smartContractStakers;
    address[] public rewardTokens;
    mapping(address => uint256) public periodFinishForToken;
    mapping(address => uint256) public rewardRateForToken;
    mapping(address => uint256) public lastUpdateTimeForToken;
    mapping(address => uint256) public rewardPerTokenStoredForToken;
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaidForToken;
    mapping(address => mapping(address => uint256)) public rewardsForToken;

    event RewardAdded(address rewardToken, uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address rewardToken, uint256 reward);
    event RewardDenied(address indexed user, address rewardToken, uint256 reward);
    event SmartContractRecorded(address indexed smartContractAddress, address indexed smartContractInitiator);

    modifier updateRewards(address _user) {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            rewardPerTokenStoredForToken[rewardToken] = rewardPerToken(rewardToken);
            lastUpdateTimeForToken[rewardToken] = lastTimeRewardApplicable(rewardToken);
            if (_user != address(0)) {
                rewardsForToken[rewardToken][_user] = earned(rewardToken, _user);
                userRewardPerTokenPaidForToken[rewardToken][_user] = rewardPerTokenStoredForToken[rewardToken];
            }
        }
        _;
    }

    modifier updateReward(address _user, address _rewardToken){
        rewardPerTokenStoredForToken[_rewardToken] = rewardPerToken(_rewardToken);
        lastUpdateTimeForToken[_rewardToken] = lastTimeRewardApplicable(_rewardToken);
        if (_user != address(0)) {
            rewardsForToken[_rewardToken][_user] = earned(_rewardToken, _user);
            userRewardPerTokenPaidForToken[_rewardToken][_user] = rewardPerTokenStoredForToken[_rewardToken];
        }
        _;
    }

    // [Hardwork] setting the reward, lpToken, duration, and rewardDistribution for each pool
    constructor(
        address[] memory _rewardTokens,
        address _lpToken,
        uint256 _duration,
        address[] memory _rewardDistribution,
        address _storage,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
    public
    ERC20Detailed(_name, _symbol, _decimals)
    MultipleRewardDistributionRecipient(_rewardDistribution)
    Controllable(_storage) // only used for referencing the grey list
    {
        require(_decimals == ERC20Detailed(_lpToken).decimals(), "decimals has to be aligned with the lpToken");
        require(_rewardTokens.length != 0, "should initialize with at least 1 rewardToken");
        rewardTokens = _rewardTokens;
        lpToken = _lpToken;
        duration = _duration;
    }

    function lastTimeRewardApplicable(uint256 _index) public view returns (uint256) {
        return lastTimeRewardApplicable(rewardTokens[_index]);
    }

    function lastTimeRewardApplicable(address _rewardToken) public view returns (uint256) {
        return Math.min(block.timestamp, periodFinishForToken[_rewardToken]);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return lastTimeRewardApplicable(rewardTokens[0]);
    }

    function rewardPerToken(uint256 _index) public view returns (uint256) {
        return rewardPerToken(rewardTokens[_index]);
    }

    function rewardPerToken(address _rewardToken) public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStoredForToken[_rewardToken];
        }
        return
        rewardPerTokenStoredForToken[_rewardToken].add(
            lastTimeRewardApplicable(_rewardToken)
            .sub(lastUpdateTimeForToken[_rewardToken])
            .mul(rewardRateForToken[_rewardToken])
            .mul(1e18)
            .div(totalSupply())
        );
    }

    function earned(uint256 _index, address _user) public view returns (uint256) {
        return earned(rewardTokens[_index], _user);
    }

    function earned(address _user) public view returns (uint256) {
        return earned(rewardTokens[0], _user);
    }

    function earned(address _rewardToken, address _user) public view returns (uint256) {
        return
        stakedBalanceOf[_user]
        .mul(rewardPerToken(_rewardToken).sub(userRewardPerTokenPaidForToken[_rewardToken][_user]))
        .div(1e18)
        .add(rewardsForToken[_rewardToken][_user]);
    }

    function stake(uint256 _amount) public updateRewards(msg.sender) {
        require(_amount > 0, "Cannot stake 0");
        recordSmartContract();
        super._mint(msg.sender, _amount);
        // ERC20 is used as a staking receipt
        stakedBalanceOf[msg.sender] = stakedBalanceOf[msg.sender].add(_amount);
        IERC20(lpToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public updateRewards(msg.sender) {
        require(_amount > 0, "Cannot withdraw 0");
        super._burn(msg.sender, _amount);
        stakedBalanceOf[msg.sender] = stakedBalanceOf[msg.sender].sub(_amount);
        IERC20(lpToken).safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function exit() external {
        withdraw(Math.min(stakedBalanceOf[msg.sender], balanceOf(msg.sender)));
        getAllRewards();
    }

    /// A push mechanism for accounts that have not claimed their rewards for a long time.
    /// The implementation is semantically analogous to getReward(), but uses a push pattern
    /// instead of pull pattern.
    function pushAllRewards(address _recipient) public updateRewards(_recipient) onlyGovernance {
        bool rewardPayout = (!smartContractStakers[_recipient] || !IController(controller()).greyList(_recipient));
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 reward = earned(rewardTokens[i], _recipient);
            if (reward > 0) {
                rewardsForToken[rewardTokens[i]][_recipient] = 0;
                // If it is a normal user and not smart contract,
                // then the requirement will pass
                // If it is a smart contract, then
                // make sure that it is not on our greyList.
                if (rewardPayout) {
                    IERC20(rewardTokens[i]).safeTransfer(_recipient, reward);
                    emit RewardPaid(_recipient, rewardTokens[i], reward);
                } else {
                    emit RewardDenied(_recipient, rewardTokens[i], reward);
                }
            }
        }
    }

    function getAllRewards() public updateRewards(msg.sender) {
        recordSmartContract();
        bool rewardPayout = (!smartContractStakers[msg.sender] || !IController(controller()).greyList(msg.sender));
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _getRewardAction(rewardTokens[i], rewardPayout);
        }
    }

    function getReward(address _rewardToken) public updateReward(msg.sender, _rewardToken) {
        recordSmartContract();
        _getRewardAction(
            _rewardToken,
        // don't payout if it is a grey listed smart contract
            (!smartContractStakers[msg.sender] || !IController(controller()).greyList(msg.sender))
        );
    }

    function getReward() public {
        getReward(rewardTokens[0]);
    }

    function _getRewardAction(address _rewardToken, bool _shouldRewardPayout) internal {
        uint256 reward = earned(_rewardToken, msg.sender);
        if (reward > 0 && IERC20(_rewardToken).balanceOf(address(this)) >= reward) {
            rewardsForToken[_rewardToken][msg.sender] = 0;
            // If it is a normal user and not smart contract,
            // then the requirement will pass
            // If it is a smart contract, then
            // make sure that it is not on our greyList.
            if (_shouldRewardPayout) {
                IERC20(_rewardToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardToken, reward);
            } else {
                emit RewardDenied(msg.sender, _rewardToken, reward);
            }
        }
    }

    function addRewardToken(address _rewardToken) public onlyGovernance {
        require(getRewardTokenIndex(_rewardToken) == uint256(- 1), "Reward token already exists");
        rewardTokens.push(_rewardToken);
    }

    function removeRewardToken(address _rewardToken) public onlyGovernance {
        uint256 i = getRewardTokenIndex(_rewardToken);
        require(i != uint256(- 1), "Reward token does not exists");
        require(periodFinishForToken[rewardTokens[i]] < block.timestamp, "Can only remove when the reward period has passed");
        require(rewardTokens.length > 1, "Cannot remove the last reward token");
        uint256 lastIndex = rewardTokens.length - 1;

        // swap
        rewardTokens[i] = rewardTokens[lastIndex];

        // delete last element
        rewardTokens.length--;
    }

    // If the return value is MAX_UINT256, it means that
    // the specified reward token is not in the list
    function getRewardTokenIndex(address _rewardToken) public view returns (uint256) {
        for (uint i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == _rewardToken)
                return i;
        }
        return uint256(- 1);
    }

    function notifyTargetRewardAmount(
        address _rewardToken,
        uint256 _reward
    )
    public
    onlyRewardDistribution
    updateRewards(address(0))
    {
        // overflow fix according to https://sips.synthetix.io/sips/sip-77
        require(_reward < uint(- 1) / 1e18, "the notified reward cannot invoke multiplication overflow");

        uint256 i = getRewardTokenIndex(_rewardToken);
        require(i != uint256(- 1), "rewardTokenIndex not found");

        if (block.timestamp >= periodFinishForToken[_rewardToken]) {
            rewardRateForToken[_rewardToken] = _reward.div(duration);
        } else {
            uint256 remaining = periodFinishForToken[_rewardToken].sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRateForToken[_rewardToken]);
            rewardRateForToken[_rewardToken] = _reward.add(leftover).div(duration);
        }
        lastUpdateTimeForToken[_rewardToken] = block.timestamp;
        periodFinishForToken[_rewardToken] = block.timestamp.add(duration);
        emit RewardAdded(_rewardToken, _reward);
    }

    function rewardTokensLength() public view returns (uint256){
        return rewardTokens.length;
    }

    /**
     * Harvest Smart Contract recording
     */
    function recordSmartContract() internal {
        if (tx.origin != msg.sender) {
            smartContractStakers[msg.sender] = true;
            emit SmartContractRecorded(msg.sender, tx.origin);
        }
    }

}
