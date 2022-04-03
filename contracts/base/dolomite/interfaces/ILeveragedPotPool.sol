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


interface ILeveragedPotPool {

    function initializeLeveragedPotPool(
        address _dolomiteMargin,
        address[] calldata _rewardTokens,
        address _lpToken,
        uint256 _duration,
        address[] calldata _rewardDistribution,
        address _storage
    ) external;

    function lpToken() external view returns (address);

    function getAccountNumber(
        address _user,
        uint256 _userAccountNumber
    ) external pure returns (uint256 accountNumber);

    function notifyStake(
        address _user,
        uint256 _userAccountNumber,
        uint256 _fAmountWei
    ) external;

    function notifyWithdraw(
        address _user,
        uint256 _userAccountNumber,
        uint256 _fAmountWei
    ) external;
}
