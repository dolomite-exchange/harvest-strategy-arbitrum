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

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./lib/Require.sol";

contract DolomiteYieldFarmingMarginRouter {
    using SafeERC20 for IERC20;
    using Require for *;

    bytes32 public constant FILE = "DolomiteYieldFarmingMarginRouter";

    address public transformerInternal;
    address public reverterInternal;

    constructor(
        address _transformerInternal,
        address _reverterInternal
    ) public {
        transformerInternal = _transformerInternal;
        reverterInternal = _reverterInternal;
    }

    function startFarming(
        address[] calldata tokens,
        uint[] calldata depositAmounts,
        uint[] calldata borrowAmounts,
        address transformer,
        bool shouldStakeFToken
    ) external {
        Require.that(
            tokens.length == depositAmounts.length,
            FILE,
            "invalid token length"
        );
        Require.that(
            depositAmounts.length == borrowAmounts.length,
            FILE,
            "invalid deposit amounts length"
        );
        // TODO deposit all depositAmounts into the protocol
        // TODO withdraw all depositAmounts + borrowAmounts to `transformerInternal`
        // TODO SELL 0 wei of marketId0 for `transformer` fToken, encode bytes as data
        // TODO stake upon completion if needed
    }

    function endFarming(
        uint fAmountWei,
        address[] calldata outputTokens,
        address transformer,
        bool shouldRemoveFTokenStake
    ) external {
        // TODO remove stake if needed
        // TODO SELL `fToken` `fAmountWei` for `marketId` 0, encode bytes as data
        // TODO deposit all outputTokens into the protocol from `transformerInternal` address
        // TODO withdraw all `outputTokens` back to msg.sender
    }

    /**
     * @param user the address of the user that will be farming
     * @return the account number used for all interim deposits, withdrawals, etc. for the this user farming
     */
    function getAccountNumber(address user) public view returns (uint) {
        return uint(keccak256(abi.encodePacked(address(this), user)));
    }

}
