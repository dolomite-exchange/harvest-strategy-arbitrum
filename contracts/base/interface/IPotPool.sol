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

import "./MultipleRewardDistributionRecipient.sol";


interface IPotPool {
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function lpToken() public view returns (address);

    function duration() public view returns (uint256);

    function stakedBalanceOf(address _user) public view returns (uint);

    function smartContractStakers(address _user) public view returns (bool);

    function rewardTokens(uint _index) public view returns (address);

    function getRewardTokens() public view returns (address[] memory);

    function periodFinishForToken(address _rewardToken) public view returns (uint);

    function rewardRateForToken(address _rewardToken) public view returns (uint);

    function lastUpdateTimeForToken(address _rewardToken) public view returns (uint);

    function rewardPerTokenStoredForToken(address _rewardToken) public view returns (uint);

    function userRewardPerTokenPaidForToken(address _rewardToken, address _user) public view returns (uint);

    function rewardsForToken(address _rewardToken, address _user) public view returns (uint);

    function lastTimeRewardApplicable(address _rewardToken) public view returns (uint256);

    function rewardPerToken(address _rewardToken) public view returns (uint256);

    function stake(uint256 _amount) public;

    function withdraw(uint256 _amount) public;

    function exit() public;

    /**
     * A push mechanism for accounts that have not claimed their rewards for a long time. The implementation is
     * semantically analogous to getReward(), but uses a push pattern instead of pull pattern.
     */
    function pushAllRewards(address _recipient) public;

    function getAllRewards() public;

    function getReward(address _rewardToken) public;

    function addRewardToken(address _rewardToken) public;

    function removeRewardToken(address _rewardToken) public;

    /**
     * @return If the return value is MAX_UINT256, it means that the specified reward token is not in the list
     */
    function getRewardTokenIndex(address _rewardToken) public view returns (uint256);

    function notifyTargetRewardAmount(address _rewardToken, uint256 _reward) public;

    function rewardTokensLength() public view returns (uint256);

    // ==================== Implementations ====================

    function lastTimeRewardApplicable(uint256 _rewardTokenIndex) public view returns (uint256) {
        return lastTimeRewardApplicable(rewardTokens(_rewardTokenIndex));
    }

    function rewardPerToken(uint256 _rewardTokenIndex) public view returns (uint256) {
        return rewardPerToken(rewardTokens(_rewardTokenIndex));
    }
}
