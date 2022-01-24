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

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../lib/DolomiteMarginAccount.sol";
import "../lib/DolomiteMarginTypes.sol";
import "../lib/Require.sol";
import "../lib/DolomiteMarginActions.sol";

contract DolomiteMarginActionHelpers {

    function _createAmountForTransfer(
        uint _amountWei
    )
    internal
    pure
    returns (DolomiteMarginTypes.AssetAmount memory) {
        return DolomiteMarginTypes.AssetAmount({
            sign : false,
            denomination : DolomiteMarginTypes.AssetDenomination.Wei,
            ref : DolomiteMarginTypes.AssetReference.Delta,
            value : _amountWei
        });
    }

    function _encodeTransfer(
        uint _accountIndexFrom,
        uint _accountIndexTo,
        uint _marketId,
        DolomiteMarginTypes.AssetAmount memory _amount
    ) internal pure returns (DolomiteMarginActions.ActionArgs memory) {
        return DolomiteMarginActions.ActionArgs({
            actionType : DolomiteMarginActions.ActionType.Transfer,
            accountId : _accountIndexFrom,
            amount : _amount,
            primaryMarketId : _marketId,
            secondaryMarketId : 0,
            otherAddress : address(0),
            otherAccountId : _accountIndexTo,
            data : bytes("")
        });
    }

}
