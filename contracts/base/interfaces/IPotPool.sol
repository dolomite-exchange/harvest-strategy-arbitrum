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


interface IPotPool {

    function initializePotPool(
        address[] calldata _rewardTokens,
        address _lpToken,
        uint256 _duration,
        address[] calldata _rewardDistribution,
        address _storage,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals
    ) external;

    function lpToken() external view returns (address);

    function duration() external view returns (uint256);

    function stakedBalanceOf(address _user) external view returns (uint);

    function smartContractStakers(address _user) external view returns (bool);

    function rewardTokens(uint _index) external view returns (address);

    function getRewardTokens() external view returns (address[] memory);

    function periodFinishForToken(address _rewardToken) external view returns (uint);

    function rewardRateForToken(address _rewardToken) external view returns (uint);

    function lastUpdateTimeForToken(address _rewardToken) external view returns (uint);

    function rewardPerTokenStoredForToken(address _rewardToken) external view returns (uint);

    function userRewardPerTokenPaidForToken(address _rewardToken, address _user) external view returns (uint);

    function rewardsForToken(address _rewardToken, address _user) external view returns (uint);

    function lastTimeRewardApplicable(address _rewardToken) external view returns (uint256);

    function rewardPerToken(address _rewardToken) external view returns (uint256);

    function stake(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function exit() external;

    /**
     * A push mechanism for accounts that have not claimed their rewards for a long time. The implementation is
     * semantically analogous to getReward(), but uses a push pattern instead of pull pattern.
     */
    function pushAllRewards(address _recipient) external;

    function getAllRewards() external;

    function getReward(address _rewardToken) external;

    function addRewardToken(address _rewardToken) external;

    function removeRewardToken(address _rewardToken) external;

    /**
     * @return If the return value is MAX_UINT256, it means that the specified reward token is not in the list
     */
    function getRewardTokenIndex(address _rewardToken) external view returns (uint256);

    function notifyTargetRewardAmount(address _rewardToken, uint256 _reward) external;

    function rewardTokensLength() external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);
}
