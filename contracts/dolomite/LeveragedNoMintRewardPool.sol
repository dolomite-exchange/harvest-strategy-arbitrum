/*

    Copyright 2021 Dolomite.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../base/SingleRewardDistributionRecipient.sol";
import "../base/inheritance/Controllable.sol";
import "../base/interface/IController.sol";

import "./interfaces/IDolomiteMargin.sol";

import "./lib/DolomiteMarginTypes.sol";
import "./lib/Require.sol";

/**
 * @notice  This contract is set up to work similar to `NoMintRewardPool`. It serves as a proxy for controlling fTokens
 *          and a user's debt (ala leverage) as well as distributing iiFARM tokens to users.
 */
contract LeveragedNoMintRewardPool is SingleRewardDistributionRecipient, Controllable {
    using Address for address;
    using SafeMath for uint;
    using Require for *;
    using SafeERC20 for IERC20;

    bytes32 public constant FILE = "LeveragedNoMintRewardPool";

    IDolomiteMargin public dolomiteMargin;
    IERC20 public rewardToken;
    IERC20 public lpToken;
    uint256 public marketId;
    uint256 public duration; // making it not a constant is less gas efficient, but portable
    uint256 public totalSupply;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    mapping(address => bool) smartContractStakers;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardDenied(address indexed user, uint256 reward);
    event SmartContractRecorded(address indexed smartContractAddress, address indexed smartContractInitiator);

    // Harvest Migration
    event Migrated(address indexed account, uint256 legacyShare, uint256 newShare);

    modifier requireIsAuthorized(address user) {
        Require.that(
            user == msg.sender || dolomiteMargin.getIsGlobalOperator(user) || dolomiteMargin.getIsLocalOperator(user, msg.sender),
            FILE,
            "unauthorized"
        );
        _;
    }

    /**
     * @notice The controller/storage only used for referencing the grey list
     */
    constructor(
        address _dolomiteMargin,
        address _rewardToken,
        address _lpToken,
        uint256 _marketId,
        uint256 _duration,
        address _rewardDistribution,
        address _storage
    ) public
    SingleRewardDistributionRecipient(_rewardDistribution)
    Controllable(_storage) {
        dolomiteMargin = IDolomiteMargin(_dolomiteMargin);
        rewardToken = IERC20(_rewardToken);
        lpToken = IERC20(_lpToken);
        marketId = _marketId;
        duration = _duration;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(lastUpdateTime)
            .mul(rewardRate)
            .mul(1e18)
            .div(_totalSupply)
        );
    }

    function earned(
        address account
    ) public view returns (uint256) {
        return
        balanceOf(account)
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
    }

    function stake(
        address user,
        uint fAmount,
        address[] memory borrowTokens,
        DolomiteMarginTypes.AssetAmount[] memory borrowAmounts
    )
    public
    requireIsAuthorized(user)
    updateReward(user) {
        _validateAmounts(borrowAmounts);
        totalSupply = totalSupply.add(fAmount);

        // TODO add staking logic for tracking how much iiFARM a user gets for staking fTokens
        // TODO transfer fToken from `user` into this contract and use `getAccountNumber`
        // TODO transfer all borrowTokens from `user` into this contract and use `getAccountNumber`
        emit Staked(user, fAmount);
    }

    function withdraw(
        address user,
        uint fAmount,
        address[] memory borrowTokens,
        DolomiteMarginTypes.AssetAmount[] memory borrowAmounts
    )
    public
    requireIsAuthorized(user)
    updateReward(user) {
        _validateAmounts(borrowAmounts);
        totalSupply = totalSupply.sub(fAmount);


        // TODO transfer fToken from `this` to `user` using `getAccountNumber`
        // TODO transfer borrowTokens from `this` to `user` using `getAccountNumber`
        emit Withdrawn(user, fAmount);
    }

    function exit(
        address user,
        address[] calldata borrowTokens
    ) external requireIsAuthorized(user) {
        recordSmartContract();
        DolomiteMarginTypes.AssetAmount[] memory borrowAmounts = new DolomiteMarginTypes.AssetAmount[](borrowTokens.length);
        for (uint i = 0; i < borrowTokens.length; i++) {
            borrowAmounts[i] = DolomiteMarginTypes.AssetAmount({
            sign : true,
            denomination : DolomiteMarginTypes.AssetDenomination.Wei,
            ref : DolomiteMarginTypes.AssetReference.Target,
            value : 0
            });
        }
        withdraw(user, balanceOf(user), borrowTokens, borrowAmounts);
        getRewardFor(user);
    }

    function balanceOf(
        address user
    ) public view returns (uint) {
        return dolomiteMargin.getAccountWei(
            DolomiteMarginAccount.Info(address(this), getAccountNumber(user, address(lpToken))),
            marketId
        ).value;
    }

    /**
     * @notice  A push mechanism for accounts that have not claimed their rewards for a long time. The implementation
     *          is semantically analogous to getReward(), but uses a push pattern instead of pull pattern.
     */
    function pushReward(
        address recipient
    )
    public
    updateReward(recipient)
    onlyGovernance {
        uint256 reward = earned(recipient);
        if (reward > 0) {
            rewards[recipient] = 0;
            // If it is a normal user and not smart contract,
            // then the requirement will pass
            // If it is a smart contract, then
            // make sure that it is not on our greyList.
            if (!recipient.isContract() || !IController(controller()).greyList(recipient)) {
                rewardToken.safeTransfer(recipient, reward);
                emit RewardPaid(recipient, reward);
            } else {
                emit RewardDenied(recipient, reward);
            }
        }
    }

    function getRewardFor(
        address user
    )
    public
    requireIsAuthorized(user)
    updateReward(user) {
        uint256 reward = earned(user);
        if (reward > 0) {
            rewards[user] = 0;
            // If it is a normal user and not smart contract, then the requirement will pass
            // If it is a smart contract, then make sure that it is not on our greyList.
            IController _controller = IController(controller());
            if (tx.origin == msg.sender || !_controller.greyList(msg.sender) || _controller.stakingWhiteList(msg.sender)) {
                rewardToken.safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, reward);
            } else {
                emit RewardDenied(msg.sender, reward);
            }
        }
    }

    function notifyRewardAmount(
        uint256 reward
    )
    external
    onlyRewardDistribution
    updateReward(address(0))
    {
        // overflow fix according to https://sips.synthetix.io/sips/sip-77
        require(reward < uint(- 1) / 1e18, "the notified reward cannot invoke multiplication overflow");

        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(duration);
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(duration);
        emit RewardAdded(reward);
    }

    // Harvest Smart Contract recording
    function recordSmartContract() internal {
        if (tx.origin != msg.sender && !smartContractStakers[msg.sender]) {
            smartContractStakers[msg.sender] = true;
            emit SmartContractRecorded(msg.sender, tx.origin);
        }
    }

    function getAccountNumber(
        address user,
        address fToken
    ) public pure returns (uint) {
        return uint(keccak256(abi.encodePacked(user, fToken)));
    }

    function _validateAmounts(
        DolomiteMarginTypes.AssetAmount[] memory borrowAmounts
    ) internal pure {
        for (uint i = 0; i < borrowAmounts.length; i++) {
            Require.that(
                !borrowAmounts[i].sign || borrowAmounts[i].value == 0,
                FILE,
                "must be negative or ZERO"
            );
        }
    }

}
