/*

    Copyright 2022 Dolomite.

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

import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";

import "../MultipleRewardDistributionRecipient.sol";
import "../inheritance/ControllableStorage.sol";
import "../interfaces/IController.sol";

import "./lib/DolomiteMarginActionsHelper.sol";

import "./interfaces/IDolomiteLiquidationCallback.sol";
import "./interfaces/IDolomiteMargin.sol";
import "./interfaces/ILeveragedPotPool.sol";

import "./lib/DolomiteMarginAccount.sol";
import "./lib/DolomiteMarginActions.sol";
import "./lib/DolomiteMarginActionsHelper.sol";
import "./lib/DolomiteMarginTypes.sol";
import "./lib/Require.sol";


contract LeveragedPotPoolV1 is
    MultipleRewardDistributionRecipient,
    ControllableStorage,
    IDolomiteLiquidationCallback,
    ILeveragedPotPool,
    ReentrancyGuard
{
    using Address for address;
    using DolomiteMarginActionsHelper for *;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant FILE = "LeveragedPotPoolV1";

    IDolomiteMargin public dolomiteMargin;
    address public lpToken;
    uint256 public marketId;
    uint256 public duration; // making it not a constant is less gas efficient, but portable
    uint256 public totalSupply;

    address[] public rewardTokens;
    mapping(address => uint256) public periodFinishForToken;
    mapping(address => uint256) public rewardRateForToken;
    mapping(address => uint256) public lastUpdateTimeForToken;
    mapping(address => uint256) public rewardPerTokenStoredForToken;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public userRewardPerTokenPaidForToken;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public rewardsForToken;

    mapping(uint256 => DolomiteMarginAccount.Info) public accountNumberToAccount;
    mapping(address => bool) smartContractStakers;

    event RewardAdded(address rewardToken, uint256 reward);
    event Staked(address indexed user, uint256 userAccountNumber, uint256 amount);
    event Withdrawn(address indexed user, uint256 userAccountNumber, uint256 amount);
    event RewardPaid(address indexed user, uint256 userAccountNumber, address rewardToken, uint256 reward);
    event RewardDenied(address indexed user, uint256 userAccountNumber, address rewardToken, uint256 reward);
    event AccountRecorded(uint256 accountNumber, address user, uint userAccountNumber);
    event SmartContractRecorded(address indexed smartContractAddress, address indexed smartContractInitiator);

    modifier requireIsGovernanceOrRewardDistribution() {
        Require.that(
            msg.sender == governance() || rewardDistribution[msg.sender],
            FILE,
            "not governance nor distributor"
        );
        _;
    }

    modifier requireIsAuthorized(address user) {
        Require.that(
            user == msg.sender || dolomiteMargin.getIsGlobalOperator(msg.sender) || dolomiteMargin.getIsLocalOperator(user, msg.sender),
            FILE,
            "unauthorized"
        );
        _;
    }

    modifier requireIsYieldFarmingRouter() {
        Require.that(
            IController(controller()).dolomiteYieldFarmingRouter() == msg.sender,
            FILE,
            "sender must be farming router",
            msg.sender
        );
        _;
    }

    modifier updateRewards(address _user, uint _userAccountNumber) {
        Require.that(
            _user != address(this),
            FILE,
            "invalid user",
            _user
        );

        uint rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            address rewardToken = rewardTokens[i];
            uint rewardPerTokenStored = rewardPerToken(rewardToken);
            rewardPerTokenStoredForToken[rewardToken] = rewardPerTokenStored;
            lastUpdateTimeForToken[rewardToken] = lastTimeRewardApplicable(rewardToken);
            if (_user != address(0)) {
                rewardsForToken[rewardToken][_user][_userAccountNumber] = earned(
                    rewardToken,
                    _user,
                    _userAccountNumber
                );
                userRewardPerTokenPaidForToken[rewardToken][_user][_userAccountNumber] = rewardPerTokenStored;
            }
        }
        _;
    }

    modifier updateReward(address _user, uint _userAccountNumber, address _rewardToken){
        uint rewardPerTokenStored = rewardPerToken(_rewardToken);
        rewardPerTokenStoredForToken[_rewardToken] = rewardPerTokenStored;
        lastUpdateTimeForToken[_rewardToken] = lastTimeRewardApplicable(_rewardToken);
        if (_user != address(0)) {
            rewardsForToken[_rewardToken][_user][_userAccountNumber] = earned(_rewardToken, _user, _userAccountNumber);
            userRewardPerTokenPaidForToken[_rewardToken][_user][_userAccountNumber] = rewardPerTokenStored;
        }
        _;
    }

    function initializeLeveragedPotPool(
        address _dolomiteMargin,
        address[] memory _rewardTokens,
        address _lpToken,
        uint256 _duration,
        address[] memory _rewardDistribution,
        address _storage
    )
    public
    initializer
    {
        MultipleRewardDistributionRecipient.initialize(_rewardDistribution);
        ControllableStorage.initializeControllable(_storage);

        require(
            _rewardTokens.length != 0,
            "should initialize with at least 1 rewardToken"
        );
        dolomiteMargin = IDolomiteMargin(_dolomiteMargin);
        rewardTokens = _rewardTokens;
        lpToken = _lpToken;
        duration = _duration;

        uint _marketId = dolomiteMargin.getMarketIdByTokenAddress(_lpToken);
        marketId = _marketId;
        Require.that(
            dolomiteMargin.getMarketIsClosing(_marketId),
            FILE,
            "market must disable borrowing",
            _marketId
        );
    }

    function lastTimeRewardApplicable(uint256 _index) public view returns (uint256) {
        return lastTimeRewardApplicable(rewardTokens[_index]);
    }

    function lastTimeRewardApplicable(address _rewardToken) public view returns (uint256) {
        return Math.min(block.timestamp, periodFinishForToken[_rewardToken]);
    }

    function rewardPerToken(uint256 _index) public view returns (uint256) {
        return rewardPerToken(rewardTokens[_index]);
    }

    function rewardPerToken(address _rewardToken) public view returns (uint256) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            return rewardPerTokenStoredForToken[_rewardToken];
        }
        return
        rewardPerTokenStoredForToken[_rewardToken].add(
            lastTimeRewardApplicable(_rewardToken)
            .sub(lastUpdateTimeForToken[_rewardToken])
            .mul(rewardRateForToken[_rewardToken])
            .mul(1e18)
            .div(_totalSupply)
        );
    }

    function earned(uint256 _index, address _user, uint _userAccountNumber) public view returns (uint256) {
        return earned(rewardTokens[_index], _user, _userAccountNumber);
    }

    function earned(address _rewardToken, address _user, uint _userAccountNumber) public view returns (uint256) {
        return
        balanceOf(_user, _userAccountNumber)
        .mul(rewardPerToken(_rewardToken).sub(userRewardPerTokenPaidForToken[_rewardToken][_user][_userAccountNumber]))
        .div(1e18)
        .add(rewardsForToken[_rewardToken][_user][_userAccountNumber]);
    }

    function notifyStake(
        address _user,
        uint _userAccountNumber,
        uint _fAmountWei
    )
    external
    nonReentrant
    requireIsYieldFarmingRouter
    updateRewards(_user, _userAccountNumber) {
        // for use by contracts like DolomiteYieldFarmingMarginRouter call this function to save gas
        _recordAccountIfNew(_user, _userAccountNumber);
        totalSupply = totalSupply.add(_fAmountWei);

        emit Staked(_user, _userAccountNumber, _fAmountWei);
    }

    function notifyWithdraw(
        address _user,
        uint _userAccountNumber,
        uint _fAmountWei
    )
    public
    nonReentrant
    requireIsYieldFarmingRouter
    updateRewards(_user, _userAccountNumber) {
        totalSupply = totalSupply.sub(_fAmountWei);
        emit Withdrawn(_user, _userAccountNumber, _fAmountWei);

        bool shouldRewardPayout = !smartContractStakers[_user] || !IController(controller()).greyList(_user);
        uint rewardTokensLength = rewardTokens.length;
        for (uint i = 0; i < rewardTokensLength; i++) {
            _getReward(rewardTokens[i], _user, _userAccountNumber, shouldRewardPayout);
        }
    }

    function onLiquidate(
        uint accountNumber,
        uint heldMarketId,
        DolomiteMarginTypes.Wei memory heldDeltaWei,
        uint,
        DolomiteMarginTypes.Wei memory
    )
    public {
        IDolomiteMargin _dolomiteMargin = dolomiteMargin;
        Require.that(
            msg.sender == address(_dolomiteMargin) || _dolomiteMargin.getIsGlobalOperator(msg.sender),
            FILE,
            "only dolomite margin can call"
        );

        DolomiteMarginAccount.Info memory user = accountNumberToAccount[accountNumber];
        Require.that(
            user.owner != address(0),
            FILE,
            "invalid user account",
            user.owner
        );

        Require.that(
            heldMarketId == marketId,
            FILE,
            "invalid market",
            heldMarketId
        );

        uint rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            address rewardToken = rewardTokens[i];
            rewardPerTokenStoredForToken[rewardToken] = rewardPerToken(rewardToken);
            lastUpdateTimeForToken[rewardToken] = lastTimeRewardApplicable(rewardToken);
            rewardsForToken[rewardToken][user.owner][user.number] = earned(rewardToken, user.owner, user.number);
            userRewardPerTokenPaidForToken[rewardToken][user.owner][user.number] =
                rewardPerTokenStoredForToken[rewardToken];
        }


        // heldDeltaWei should always be negative, but why force it?
        if (heldDeltaWei.sign) {
            totalSupply = totalSupply.add(heldDeltaWei.value);
        } else {
            totalSupply = totalSupply.sub(heldDeltaWei.value);
        }
    }

    /// A push mechanism for accounts that have not claimed their rewards for a long time.
    /// The implementation is semantically analogous to getReward(), but uses a push pattern
    /// instead of pull pattern.
    function pushAllRewards(
        address _user,
        uint _userAccountNumber
    ) public updateRewards(_user, _userAccountNumber) onlyGovernance {
        bool rewardPayout = (!smartContractStakers[_user] || !IController(controller()).greyList(_user));
        uint rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            address rewardToken = rewardTokens[i];
            uint256 reward = earned(rewardToken, _user, _userAccountNumber);
            if (reward > 0) {
                rewardsForToken[rewardToken][_user][_userAccountNumber] = 0;
                // If it is a normal user and not smart contract,
                // then the requirement will pass
                // If it is a smart contract, then
                // make sure that it is not on our greyList.
                if (rewardPayout) {
                    IERC20(rewardToken).safeTransfer(_user, reward);
                    emit RewardPaid(_user, _userAccountNumber, rewardToken, reward);
                } else {
                    emit RewardDenied(_user, _userAccountNumber, rewardToken, reward);
                }
            }
        }
    }

    function getAllRewards(
        address _user,
        uint _userAccountNumber
    )
    public
    requireIsAuthorized(_user)
    updateRewards(_user, _userAccountNumber) {
        _recordSmartContract();
        bool shouldRewardPayout = !smartContractStakers[_user] || !IController(controller()).greyList(_user);
        uint rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            _getReward(rewardTokens[i], _user, _userAccountNumber, shouldRewardPayout);
        }
    }

    function getReward(
        address _user,
        uint _userAccountNumber,
        address _rewardToken
    )
    public
    requireIsAuthorized(_user)
    updateReward(_user, _userAccountNumber, _rewardToken) {
        _recordSmartContract();
        // don't payout if it is a grey listed smart contract
        bool shouldRewardPayout = !smartContractStakers[msg.sender] || !IController(controller()).greyList(msg.sender);
        _getReward(
            _rewardToken,
            _user,
            _userAccountNumber,
            shouldRewardPayout
        );
    }

    function balanceOf(
        address _user,
        uint _userAccountNumber
    ) public view returns (uint) {
        return dolomiteMargin.getAccountWei(
            DolomiteMarginAccount.Info(address(this), getAccountNumber(_user, _userAccountNumber)),
            marketId
        ).value;
    }

    function getAccountNumber(
        address _user,
        uint _userAccountNumber
    ) public pure returns (uint) {
        return uint(keccak256(abi.encodePacked(_user, "-", _userAccountNumber)));
    }

    function addRewardToken(address _rewardToken) public requireIsGovernanceOrRewardDistribution {
        Require.that(
            getRewardTokenIndex(_rewardToken) == uint256(- 1),
            FILE,
            "reward token already exists",
            _rewardToken
        );
        rewardTokens.push(_rewardToken);
    }

    function removeRewardToken(address _rewardToken) public onlyGovernance {
        uint256 index = getRewardTokenIndex(_rewardToken);
        Require.that(
            index != uint256(- 1),
            FILE,
            "reward token does not exist",
            _rewardToken
        );
        Require.that(
            periodFinishForToken[rewardTokens[index]] < block.timestamp,
            FILE,
            "can only remove after period",
            periodFinishForToken[rewardTokens[index]],
            block.timestamp
        );
        Require.that(
            rewardTokens.length >= 2,
            FILE,
            "cannot remove last reward token"
        );
        uint256 lastIndex = rewardTokens.length - 1;

        if (index != lastIndex) {
            // swap
            rewardTokens[index] = rewardTokens[lastIndex];
        }

        // delete last element
        rewardTokens.pop();
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
    updateRewards(address(0), 0)
    {
        // overflow fix according to https://sips.synthetix.io/sips/sip-77
        Require.that(
            _reward < uint(- 1) / 1e18,
            FILE,
            "reward amount overflow",
            _reward
        );

        uint256 i = getRewardTokenIndex(_rewardToken);
        Require.that(
            i != uint256(- 1),
            FILE,
            "reward token not found",
            _rewardToken
        );

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

    // ------------------------- Internal Functions -------------------------

    function _getReward(
        address _rewardToken,
        address _user,
        uint _userAccountNumber,
        bool _shouldRewardPayout
    ) internal {
        uint256 reward = earned(_rewardToken, _user, _userAccountNumber);
        if (reward > 0 && IERC20(_rewardToken).balanceOf(address(this)) >= reward) {
            rewardsForToken[_rewardToken][_user][_userAccountNumber] = 0;
            // If it is a normal user and not smart contract,
            // then the requirement will pass
            // If it is a smart contract, then
            // make sure that it is not on our greyList.
            if (_shouldRewardPayout) {
                IERC20(_rewardToken).safeTransfer(_user, reward);
                emit RewardPaid(_user, _userAccountNumber, _rewardToken, reward);
            } else {
                emit RewardDenied(_user, _userAccountNumber, _rewardToken, reward);
            }
        }
    }

    // Harvest Smart Contract recording
    function _recordSmartContract() internal {
        if (tx.origin != msg.sender) {
            smartContractStakers[msg.sender] = true;
            emit SmartContractRecorded(msg.sender, tx.origin);
        }
    }

    function _recordAccountIfNew(
        address _user,
        uint256 _userAccountNumber
    ) internal {
        uint accountNumber = getAccountNumber(_user, _userAccountNumber);
        if (accountNumberToAccount[accountNumber].owner == address(0)) {
            accountNumberToAccount[accountNumber] = DolomiteMarginAccount.Info(_user, _userAccountNumber);
            emit AccountRecorded(accountNumber, _user, _userAccountNumber);
        }
    }

    function _validateAmounts(
        DolomiteMarginTypes.AssetAmount[] memory _borrowAmounts,
        address[] memory _borrowTokens
    ) internal pure {
        Require.that(
            _borrowTokens.length == _borrowAmounts.length,
            FILE,
            "invalid borrow lengths",
            _borrowTokens.length,
            _borrowAmounts.length
        );
        for (uint i = 0; i < _borrowAmounts.length; i++) {
            Require.that(
                !_borrowAmounts[i].sign || _borrowAmounts[i].value == 0,
                FILE,
                "must be negative or ZERO"
            );
        }
    }
}
